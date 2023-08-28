WITH
    marketraws as (SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_1_evt_MarketExecuted WHERE open = True
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_evt_MarketExecuted WHERE open = True
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_1_evt_MarketExecuted WHERE open = True
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_evt_MarketExecuted WHERE open = True
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_2_evt_MarketExecuted WHERE open = True
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_1_evt_MarketExecuted WHERE open = True
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_evt_MarketExecuted WHERE open = True
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV5_evt_MarketExecuted WHERE open = True),
    
    limitraws as (SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_1_evt_LimitExecuted WHERE daiSentToTrader = CAST(0 as UINT256) AND orderType != 2
    UNION ALL 
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_arbitrum.GNSTradingCallbacksV6_3_evt_LimitExecuted WHERE daiSentToTrader = CAST(0 as UINT256) AND orderType != 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_1_evt_LimitExecuted WHERE daiSentToTrader = CAST(0 as UINT256) AND orderType != 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_3_evt_LimitExecuted WHERE daiSentToTrader = CAST(0 as UINT256) AND orderType != 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_2_evt_LimitExecuted WHERE daiSentToTrader = CAST(0 as UINT256) AND orderType != 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_1_evt_LimitExecuted WHERE daiSentToTrader = CAST(0 as UINT256) AND orderType != 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV6_evt_LimitExecuted WHERE percentProfit = CAST(0 as INT256) AND orderType != 2
    UNION ALL
    SELECT regexp_split(t, '[,":]') as trade, evt_block_time, orderType, positionSizeDai as ps_dai, evt_tx_hash FROM gains_network_polygon.GNSTradingCallbacksV5_evt_LimitExecuted WHERE percentProfit = CAST(0 as INT256) AND orderType != 2),

    labelpairs as (SELECT concat("from", '_', to) as label, index FROM gains_network_arbitrum.GNSPairsStorageV6_evt_PairAdded),

    markettrades as (SELECT evt_block_time as block_time,
        evt_tx_hash as hash,
        ps_dai/1e18 as ps_dai,
        trade[5] as address,
        trade[10] as pair_index,
        case when trade[30] = 'true' then 'LONG' else 'SHORT' end as position_side,
        CAST(trade[34] as INT) as leverage
    FROM marketraws),

    limittrades as (SELECT evt_block_time as block_time,
        evt_tx_hash as hash,
        ps_dai/1e18 as ps_dai,
        trade[5] as address,
        trade[10] as pair_index,
        case 
            when trade[30] = 'true' then 'LONG'
            when trade[30] = 'false'  then 'SHORT'
            else 'unknwown' end as position_side,
        CAST(trade[34] as INT) as leverage
    FROM limitraws),

    merged_trades as (SELECT * FROM markettrades WHERE NOT regexp_like(pair_index, '^(2[1-9]|30|58|59|6[0-9]|7[0-9]|8[0-9]|9[0-9]|100|101)$') UNION ALL SELECT * FROM limittrades WHERE NOT regexp_like(pair_index, '^(2[1-9]|30|58|59|6[0-9]|7[0-9]|8[0-9]|9[0-9]|100|101)$')),

    labeled_trades as (SELECT block_time,
        b.label as virtual_asset,
        hash,
        ps_dai,
        address,
        ps_dai * leverage as volume,
        position_side
    FROM merged_trades a left join labelpairs b on a.pair_index = CAST(b.index as VARCHAR)),


    formatted_trades as (SELECT virtual_asset, block_time, address, volume, ps_dai as collateral, position_side as side, 'OPEN' as trade_type FROM labeled_trades)

SELECT * FROM formatted_trades;