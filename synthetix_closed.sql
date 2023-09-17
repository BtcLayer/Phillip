WITH 

asset_prices as (
  SELECT 
    position_modified.evt_block_time as time, 
    position_modified.contract_address, 
    from_utf8(
      bytearray_rtrim(market_added.asset)
    ) as asset, 
    AVG(lastPrice / 1e18) as price 
  FROM 
    synthetix_futuresmarket_optimism.ProxyPerpsV2_evt_PositionModified as position_modified 
    LEFT JOIN synthetix_optimism.FuturesMarketManager_evt_MarketAdded as market_added ON position_modified.contract_address = market_added.market 
  GROUP BY 1, 2, 3
),

tracking_positions as (
    SELECT 
        evt_tx_hash, 
        fee, 
        sizeDelta 
    FROM 
        synthetix_futuresmarket_optimism.ProxyPerpsV2_evt_PerpsTracking 
    ),

trades as (
    SELECT positions.evt_block_time, 
        account as address, 
        asset_prices.asset as virtual_asset, 
        (tradeSize/1e18) * price as sizeDai,
        ABS(tradeSize) / 1e18 * asset_prices.price as volume, 
        (CASE WHEN CAST(positions.tradeSize as double) > 0 THEN 'LONG' WHEN CAST(positions.tradeSize as double) < 0 then 'SHORT' END) as position_side, 
        (CASE WHEN CAST(positions.margin as double) >= 0 AND CAST(positions.size as double) = 0 AND ABS(CAST(positions.tradeSize as double)) > 0 AND positions.size != positions.tradeSize THEN 'close' ELSE 'open' END) AS position_type, 
        ID, 
        ROW_NUMBER() OVER (
            PARTITION BY id, 
            account 
            ORDER BY 
            evt_block_number
        ) as row_num, 
        positions.fee / 1e18 as fees 
    FROM 
        synthetix_futuresmarket_optimism.ProxyPerpsV2_evt_PositionModified as positions 
        JOIN asset_prices ON positions.contract_address = asset_prices.contract_address 
    AND positions.evt_block_time = asset_prices.time 
        JOIN tracking_positions ON positions.evt_tx_hash = tracking_positions.evt_tx_hash 
    AND positions.fee = tracking_positions.fee 
    AND positions.tradeSize = tracking_positions.sizeDelta 
    WHERE 
        ABS(tradeSize) / 1e18 <> 0
), 

liquidations as (
  SELECT 
    liquidations.evt_block_time, 
    account as trader, 
    virtual_asset, 
    (size/1e18) * (price/1e18) as sizeDai,
    abs(
      liquidations.size / 1e18
    ) * price / 1e18 as volume, 
    IF(
      liquidations.size / 1e18 > 0, 
      'LONG', 'SHORT'
    ) as position_side, 
    'LIQUIDATION' as position_type, 
    fee / 1e18 as fees 
  FROM 
    synthetix_futuresmarket_optimism.ProxyPerpsV2_evt_PositionLiquidated as liquidations 
    JOIN (
      SELECT 
        id, 
        address, 
        virtual_asset 
      FROM 
        trades 
      where 
        row_num = 1
    ) as all_liquidation_trades ON liquidations.id = all_liquidation_trades.id 
    and liquidations.account = all_liquidation_trades.address
),

joined_trades as (SELECT evt_block_time, address, virtual_asset, sizeDai, volume, position_side, position_type, fees FROM trades
    UNION ALL 
    SELECT * FROM liquidations
),

pnltrades as (SELECT
    virtual_asset,
    evt_block_time as block_time,
    address,
    volume,
    fees as fee,
    case
        when position_type = 'LIQUIDATION' then -abs(sizeDai)
        else sizeDai
    end as pnl,
    case
        when position_type = 'LIQUIDATION' then -100
        else ((sizeDai)/volume) * 100
    end as pnl_percent,
    position_side,
    case   
        when position_type = 'LIQUIDATION' then 'Yes'
        else 'No' 
    end as liquidation
    FROM joined_trades WHERE position_type = 'close' OR position_type = 'LIQUIDATION'
),

returndata as (SELECT sum(a.volume) as sum_vol, a.address as address from pnltrades a right join pnltrades b on a.address = b.address GROUP BY a.address),
returntrades as (SELECT 
    virtual_asset,
    block_time,
    a.address as address,
    round(volume, 2) as volume,
    round(fee, 2) as fee,
    round(pnl, 2) as pnl,
    round(pnl_percent, 2) as pnl_percent,
    position_side,
    liquidation,
    round(100 * pnl / sum_vol, 2) as return
FROM pnltrades a left join returndata b on a.address = b.address),

ordered as (SELECT address,
        AVG(pnl) as avg_pnl,
        COUNT(*) as freq,
        SUM(pnl) as sum_pnl,
        CAST(SUM(pnl)/SUM(volume) AS DECIMAL(14, 3)) as pnltovol,
        CAST(approx_percentile(pnl, 0.5)/approx_percentile(volume,0.5) AS DECIMAL(14,3)) as medianpnltovol
    FROM (SELECT address,
        pnl,
        volume,
        block_time,
        approx_percentile(pnl, 0.98) OVER (PARTITION BY address) as threshold_pnl
    FROM returntrades) as percentile_trades
    WHERE
        pnl <= threshold_pnl
    GROUP BY address
    HAVING
        AVG(volume) > 2500
        AND COUNT(*) >= 40
        AND SUM(pnl) > 10000
        AND max(block_time) >= (NOW() - INTERVAL '3' MONTH))
    
SELECT * FROM ordered;
