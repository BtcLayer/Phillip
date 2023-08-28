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

tracking_v1_positions as (
    SELECT evt_tx_hash, fee, sizeDelta
    FROM synthetix_optimism.FuturesMarket_evt_FuturesTracking
),

v1_trades as (
    SELECT positions.evt_block_time, 
        account as address, 
        asset_prices.asset as virtual_asset, 
        size,
        ABS(tradeSize)/1e18 * asset_prices.price as volume, 
        (CASE WHEN CAST(positions.tradeSize as double) > 0 THEN 'LONG' WHEN CAST(positions.tradeSize as double) < 0 then 'SHORT' END) as position_side, 
        (CASE WHEN CAST(positions.margin as double) >= 0 AND CAST(positions.size as double) = 0 AND ABS(CAST(positions.tradeSize as double)) > 0 AND positions.size != positions.tradeSize THEN 'CLOSE' ELSE 'OPEN' END) AS position_type, 
        id, 
        ROW_NUMBER() OVER (PARTITION BY id, account ORDER BY evt_block_number) as row_num, 
        POSITIONS.fee/1e18 as fees
    FROM synthetix_optimism.FuturesMarket_evt_PositionModified as positions
    Join asset_prices
        ON positions.contract_address = asset_prices.contract_address
        AND positions.evt_block_time = asset_prices.time
    JOIN tracking_v1_positions
        ON positions.evt_tx_hash = tracking_v1_positions.evt_tx_hash
        AND positions.fee = tracking_v1_positions.fee
        AND positions.tradeSize = tracking_v1_positions.sizeDelta
    WHERE CAST(positions.tradeSize AS DECIMAL) <> 0
), 

tracking_v2_positions as (
    SELECT 
        evt_tx_hash, 
        fee, 
        sizeDelta 
    FROM 
        synthetix_futuresmarket_optimism.ProxyPerpsV2_evt_PerpsTracking 
    ),

v2_trades as (
    SELECT positions.evt_block_time, 
        account as address, 
        asset_prices.asset as virtual_asset, 
        size,
        ABS(tradeSize) / 1e18 * asset_prices.price as volume, 
        (CASE WHEN CAST(positions.tradeSize as double) > 0 THEN 'LONG' WHEN CAST(positions.tradeSize as double) < 0 then 'SHORT' END) as position_side, 
        (CASE WHEN CAST(positions.margin as double) >= 0 AND CAST(positions.size as double) = 0 AND ABS(CAST(positions.tradeSize as double)) > 0 AND positions.size != positions.tradeSize THEN 'CLOSE' ELSE 'OPEN' END) AS position_type, 
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
        JOIN tracking_v2_positions ON positions.evt_tx_hash = tracking_v2_positions.evt_tx_hash 
    AND positions.fee = tracking_v2_positions.fee 
    AND positions.tradeSize = tracking_v2_positions.sizeDelta 
    WHERE 
        ABS(tradeSize) / 1e18 <> 0
), 

trades as (SELECT * FROM v1_trades 
    UNION ALL 
    SELECT * FROM v2_trades
),

formatted as (SELECT
    virtual_asset,
    evt_block_time as block_time,
    address,
    volume,
    size / 1e18 as collateral,
    fees as fee,
    position_side as side,
    position_type as trade_type
    FROM trades WHERE position_type = 'OPEN'
)

SELECT * FROM formatted;