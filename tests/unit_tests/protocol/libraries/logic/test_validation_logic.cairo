%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.protocol.libraries.helpers.helpers import update_struct
from contracts.protocol.libraries.logic.validation_logic import ValidationLogic
from contracts.protocol.libraries.types.data_types import DataTypes
from contracts.protocol.libraries.configuration.reserve_configuration import ReserveConfiguration

from tests.utils.constants import (
    MOCK_TOKEN_1,
    MOCK_A_TOKEN_1,
    BASE_LIQUIDITY_INDEX,
    STABLE_DEBT_TOKEN_ADDRESS,
    VARIABLE_DEBT_TOKEN_ADDRESS,
    INTEREST_RATE_STRATEGY_ADDRESS,
    VARIABLE_BORROW_INDEX,
)

func get_test_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve : DataTypes.ReserveData
):
    return (
        DataTypes.ReserveData(BASE_LIQUIDITY_INDEX, 0, VARIABLE_BORROW_INDEX, 0, 0, 0, 0, MOCK_A_TOKEN_1, STABLE_DEBT_TOKEN_ADDRESS, VARIABLE_DEBT_TOKEN_ADDRESS, INTEREST_RATE_STRATEGY_ADDRESS, 0, 0, 0),
    )
end

func mock_supply_zero{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reserve : DataTypes.ReserveData
):
    %{
        stop_mock = mock_call(ids.reserve.a_token_address,"totalSupply",[0,0])
        stop_mock = mock_call(ids.reserve.stable_debt_token_address,"total_supply",[0,0])
        stop_mock = mock_call(ids.reserve.variable_debt_token_address,"total_supply",[0,0])
    %}
    return ()
end

@external
func test_validate_supply_when_reserve_is_inactive{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    %{ expect_revert(error_message="RESERVE_INACTIVE") %}
    ValidationLogic.validate_supply(reserve, Uint256(100, 0))
    return ()
end

@external
func test_validate_withdraw_when_reserve_is_inactive{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    %{ expect_revert(error_message="RESERVE_INACTIVE") %}
    ValidationLogic.validate_withdraw(reserve, Uint256(100, 0), Uint256(1000, 0))
    return ()
end

@external
func test_validate_supply_when_reserve_is_active{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    let (reserve) = get_test_reserve()
    ReserveConfiguration.set_active(MOCK_A_TOKEN_1, TRUE)
    ValidationLogic.validate_supply(reserve, Uint256(100, 0))
    return ()
end

@external
func test_validate_withdraw_when_reserve_is_active{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    let (reserve) = get_test_reserve()
    ReserveConfiguration.set_active(MOCK_A_TOKEN_1, TRUE)
    ValidationLogic.validate_withdraw(reserve, Uint256(100, 0), Uint256(1000, 0))
    return ()
end

@external
func test_validate_supply_when_reserve_is_frozen{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    let (reserve) = get_test_reserve()
    ReserveConfiguration.set_active(MOCK_A_TOKEN_1, TRUE)
    ReserveConfiguration.set_frozen(MOCK_A_TOKEN_1, TRUE)
    %{ expect_revert(error_message="RESERVE_FROZEN") %}
    ValidationLogic.validate_supply(reserve, Uint256(100, 0))
    return ()
end

@external
func test_validate_supply_when_asset_is_paused{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    let (reserve) = get_test_reserve()
    ReserveConfiguration.set_active(MOCK_A_TOKEN_1, TRUE)
    ReserveConfiguration.set_paused(MOCK_A_TOKEN_1, TRUE)
    %{ expect_revert(error_message="RESERVE_PAUSED") %}
    ValidationLogic.validate_supply(reserve, Uint256(100, 0))
    return ()
end

@external
func test_validate_withdraw_when_asset_is_paused{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    let (reserve) = get_test_reserve()
    ReserveConfiguration.set_active(MOCK_A_TOKEN_1, TRUE)
    ReserveConfiguration.set_paused(MOCK_A_TOKEN_1, TRUE)
    %{ expect_revert(error_message="RESERVE_PAUSED") %}
    ValidationLogic.validate_withdraw(reserve, Uint256(100, 0), Uint256(1000, 0))
    return ()
end

@external
func test_validate_supply_amount_null{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    %{ expect_revert(error_message="INVALID_AMOUNT") %}
    ValidationLogic.validate_supply(reserve, Uint256(0, 0))
    return ()
end

@external
func test_validate_drop_reserve_zero_address{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    %{ expect_revert(error_message="Zero address not valid") %}
    ValidationLogic.validate_drop_reserve(reserve, 0)
    return ()
end

@external
func test_validate_drop_reserve_asset_listed_1{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    let (local reserve) = get_test_reserve()
    # Test 1 : reserve.id != 0 => asset is listed

    # update reserve.id to 1
    let (__fp__, _) = get_fp_and_pc()
    let (updated_reserve_ptr : DataTypes.ReserveData*) = update_struct(
        &reserve, DataTypes.ReserveData.SIZE, new (1), 6
    )
    mock_supply_zero(reserve)
    ValidationLogic.validate_drop_reserve([updated_reserve_ptr], MOCK_TOKEN_1)
    return ()
end

@external
func test_validate_drop_reserve_asset_listed_2{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    let (contract_address) = get_contract_address()

    # Test 2 : reserve_list[0] == asset => asset is listed

    %{
        # store asset in reserve_list[0]. mock aToken supply
        store(ids.contract_address, "reserves_list",[ids.MOCK_TOKEN_1], key=[0])
    %}
    mock_supply_zero(reserve)
    ValidationLogic.validate_drop_reserve(reserve, MOCK_TOKEN_1)
    return ()
end

@external
func test_validate_drop_reserve_asset_not_listed{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    # reserve.id === 0 and reserves_list[0] != asset => asset is not listed
    %{ expect_revert(error_message="Asset is not listed") %}
    ValidationLogic.validate_drop_reserve(reserve, MOCK_TOKEN_1)
    return ()
end

@external
func test_validate_drop_reserve_stable_debt_supply_not_zero{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    let (contract_address) = get_contract_address()
    %{
        store(ids.contract_address, "reserves_list",[ids.MOCK_TOKEN_1], key=[0])
        stop_mock = mock_call(ids.reserve.stable_debt_token_address,"total_supply",[10,0])
        expect_revert(error_message="Stable debt supply is not zero")
    %}
    ValidationLogic.validate_drop_reserve(reserve, MOCK_TOKEN_1)
    return ()
end

@external
func test_validate_drop_reserve_atoken_supply_not_zero{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    let (reserve) = get_test_reserve()
    let (contract_address) = get_contract_address()
    %{
        store(ids.contract_address, "reserves_list",[ids.MOCK_TOKEN_1], key=[0])
        stop_mock = mock_call(ids.reserve.stable_debt_token_address,"total_supply",[0,0])
        stop_mock = mock_call(ids.reserve.variable_debt_token_address,"total_supply",[0,0])
        stop_mock = mock_call(ids.reserve.a_token_address,"totalSupply",[10,0])
        expect_revert(error_message="AToken supply is not zero")
    %}
    ValidationLogic.validate_drop_reserve(reserve, MOCK_TOKEN_1)
    return ()
end
