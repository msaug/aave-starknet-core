%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.protocol.libraries.helpers.constants import empty_reserve_configuration
from contracts.protocol.libraries.logic.reserve_logic import ReserveLogic
from contracts.protocol.libraries.types.data_types import DataTypes

from tests.utils.constants import (
    BASE_LIQUIDITY_INDEX,
    INTEREST_RATE_STRATEGY_ADDRESS,
    MOCK_A_TOKEN_1,
    STABLE_DEBT_TOKEN_ADDRESS,
    VARIABLE_BORROW_INDEX,
    VARIABLE_DEBT_TOKEN_ADDRESS,
)

@view
func test_init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (empty_config) = empty_reserve_configuration();
    let (new_reserve) = ReserveLogic.init(
        DataTypes.ReserveData(empty_config, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        MOCK_A_TOKEN_1,
        STABLE_DEBT_TOKEN_ADDRESS,
        VARIABLE_DEBT_TOKEN_ADDRESS,
        INTEREST_RATE_STRATEGY_ADDRESS,
    );
    assert new_reserve = DataTypes.ReserveData(empty_config, BASE_LIQUIDITY_INDEX, 0, VARIABLE_BORROW_INDEX, 0, 0, 0, 0, MOCK_A_TOKEN_1, STABLE_DEBT_TOKEN_ADDRESS, VARIABLE_DEBT_TOKEN_ADDRESS, INTEREST_RATE_STRATEGY_ADDRESS, 0, 0, 0);

    return ();
}

@view
func test_init_already_initialized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    let (empty_config) = empty_reserve_configuration();
    %{ expect_revert() %}
    let (new_reserve) = ReserveLogic.init(
        DataTypes.ReserveData(empty_config, BASE_LIQUIDITY_INDEX, 0, 0, 0, 0, 0, 0, MOCK_A_TOKEN_1, 0, 0, 0, 0, 0, 0),
        MOCK_A_TOKEN_1,
        STABLE_DEBT_TOKEN_ADDRESS,
        VARIABLE_DEBT_TOKEN_ADDRESS,
        INTEREST_RATE_STRATEGY_ADDRESS,
    );
    return ();
}
