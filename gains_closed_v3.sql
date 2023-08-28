WITH 

    -- Collecting MarketExecuted Data for all Arbitrum contract versions and Polygon contract versions 6.1 and upwards
    new_marketraws as (SELECT regexp_split(t, '[,":]') as trade, evt_block_time, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_1_evt_MarketExecuted WHERE open = False
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_evt_MarketExecuted WHERE open = False
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_1_evt_MarketExecuted WHERE open = False
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_evt_MarketExecuted WHERE open = False
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_2_evt_MarketExecuted WHERE open = False
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_1_evt_MarketExecuted WHERE open = False),

    -- Collecting MarketExecuted Data for Polygon contract versions 5 and 6 (missing daiSentToTrader column)
    old_marketraws as (SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_evt_MarketExecuted WHERE open = False
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV5_evt_MarketExecuted WHERE open = False),

    -- Joining the Polygon v5+6 MarketExecuted Data with daiSentToTrader column from the Trading Vault
    daiSent_old_marketraws as (SELECT a.trade, a.evt_block_time, COALESCE(b.amount, CAST(0 as UINT256)) as daiSentToTrader, a.ps_dai, a.evt_tx_hash FROM old_marketraws a left join gains_network_polygon.GNSTradingVaultV5_evt_Sent b on a.evt_tx_hash = b.evt_tx_hash),
    marketraws as (SELECT * FROM new_marketraws UNION ALL SELECT * FROM daiSent_old_marketraws),

    -- Collecting LimitExecuted Data for all Arbitrum contract versions and Polygon contract versions 6.1 and upwards
    new_limitraws as (SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_1_evt_LimitExecuted WHERE daiSentToTrader != CAST(0 as UINT256) OR orderType = 2
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_evt_LimitExecuted WHERE daiSentToTrader != CAST(0 as UINT256) OR orderType = 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_1_evt_LimitExecuted WHERE daiSentToTrader != CAST(0 as UINT256) OR orderType = 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_evt_LimitExecuted WHERE daiSentToTrader != CAST(0 as UINT256) OR orderType = 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_2_evt_LimitExecuted WHERE daiSentToTrader != CAST(0 as UINT256) OR orderType = 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, daiSentToTrader, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_1_evt_LimitExecuted WHERE daiSentToTrader != CAST(0 as UINT256) OR orderType = 2),
    
    -- Collecting MarketExecuted Data for Polygon contract versions 5 and 6 (missing daiSentToTrader column)
    old_limitraws as (SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_evt_LimitExecuted WHERE percentProfit != CAST(0 as INT256)
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV5_evt_LimitExecuted WHERE percentProfit != CAST(0 as INT256)),

    -- Joining the Polygon v5+6 LimitExecuted Data with daiSentToTrader column from the Trading Vault
    daiSent_old_limitraws as (SELECT a.trade, a.evt_block_time, a.orderType, COALESCE(b.amount, CAST(0 as UINT256)) as daiSentToTrader, a.ps_dai, a.evt_tx_hash FROM old_limitraws a left join gains_network_polygon.GNSTradingVaultV5_evt_Sent b on a.evt_tx_hash = b.evt_tx_hash),
    limitraws as (SELECT * FROM new_limitraws UNION ALL SELECT * FROM daiSent_old_limitraws),

    -- Grabbing the traded virtual asset with the responding id
    labelpairs as (SELECT concat("from", '_', to) as label, index FROM gains_network_arbitrum.GNSPairsStorageV6_evt_PairAdded),
    
    -- Formatting the market trades
    markettrades as (SELECT evt_block_time as block_time,
        evt_tx_hash as hash,
        daiSentToTrader/1e18 as dai_sent,
        ps_dai/1e18 as ps_dai,
        trade[5] as address,
        trade[10] as pair_index,
        case when trade[30] = 'true' then 'LONG' else 'SHORT' end as position_side,
        'No' as liquidation,
        CAST(trade[34] as INT) as leverage
    FROM marketraws),

    -- Formatting the limit trades
    limittrades as (SELECT evt_block_time as block_time,
        evt_tx_hash as hash,
        daiSentToTrader/1e18 as dai_sent,
        ps_dai/1e18 as ps_dai,
        trade[5] as address,
        trade[10] as pair_index,
        case 
            when orderType = 2 then 'LIQUIDATION'
            when trade[30] = 'true' then 'LONG'
            when trade[30] = 'false' then 'SHORT'
        end as position_side,
        case when orderType = 2 then 'Yes' else 'No' end as liquidation,
        CAST(trade[34] as INT) as leverage
    FROM limitraws),

    -- Merging market and limit trades
    merged_trades as (SELECT * FROM markettrades WHERE NOT regexp_like(pair_index, '^(2[1-9]|30|58|59|6[0-9]|7[0-9]|8[0-9]|9[0-9]|100|101)$') UNION ALL SELECT * FROM limittrades WHERE NOT regexp_like(pair_index, '^(2[1-9]|30|58|59|6[0-9]|7[0-9]|8[0-9]|9[0-9]|100|101)$')),

    -- Matching the traded virtual asset to the order and further formatting
    labeled_trades as (SELECT b.label as virtual_asset,
        block_time,
        address,
        ps_dai * leverage as volume,
        hash,
        case
            when liquidation = 'Yes' then -ps_dai
            when dai_sent != 0 then dai_sent - ps_dai
        end as pnl,
        case
            when liquidation = 'Yes' then (-ps_dai * 100)/(ps_dai * leverage)
            when dai_sent != 0 then ((dai_sent - ps_dai) * 100)/(ps_dai * leverage)
        end as pnl_percent,
        position_side,
        liquidation
    FROM merged_trades a left join labelpairs b on a.pair_index = CAST(b.index as VARCHAR)),
    
    returndata as (SELECT sum(volume) as sum_vol, address from labeled_trades GROUP BY address),

    returntrades as (SELECT virtual_asset,
        block_time,
        a.address as address,
        round(volume, 2) as volume,
        0 as fee, -- round(fee/1e18, 2)
        round(pnl, 2) as pnl,
        round(pnl_percent, 2) as pnl_percent,
        position_side,
        liquidation,
        round(pnl_percent * (volume/sum_vol), 3) as return
    FROM labeled_trades a left join returndata b on a.address = b.address),
    
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