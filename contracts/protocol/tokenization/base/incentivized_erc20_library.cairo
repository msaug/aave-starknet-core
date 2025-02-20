%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le_felt, assert_not_zero
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.token.erc20.library import Approval, ERC20, Transfer

from contracts.interfaces.i_aave_incentives_controller import IAaveIncentivesController
from contracts.interfaces.i_acl_manager import IACLManager
from contracts.interfaces.i_pool import IPool
from contracts.interfaces.i_pool_addresses_provider import IPoolAddressesProvider
from contracts.protocol.libraries.helpers.errors import Errors
from contracts.protocol.libraries.math.felt_math import to_felt, to_uint256
from contracts.protocol.libraries.types.data_types import DataTypes

//
// Storage
//

@storage_var
func IncentivizedERC20_pool() -> (pool: felt) {
}

@storage_var
func IncentivizedERC20_user_state(address: felt) -> (state: DataTypes.UserState) {
}

@storage_var
func IncentivizedERC20_allowances(delegator: felt, delegatee: felt) -> (allowance: Uint256) {
}

@storage_var
func IncentivizedERC20_total_supply() -> (total_supply: Uint256) {
}

@storage_var
func IncentivizedERC20_incentives_controller() -> (incentives_controller: felt) {
}

@storage_var
func IncentivizedERC20_addresses_provider() -> (addresses_provider: felt) {
}

@storage_var
func IncentivizedERC20_owner() -> (owner: felt) {
}

namespace IncentivizedERC20 {
    //
    // Modifiers
    //

    //
    // @dev Only pool admin can call functions marked by this modifier.
    //
    func assert_only_pool_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (caller) = get_caller_address();
        let (address_provider) = IncentivizedERC20_addresses_provider.read();
        let (acl_manager_address) = IPoolAddressesProvider.get_ACL_manager(
            contract_address=address_provider
        );
        let (is_pool_admin) = IACLManager.is_pool_admin(
            contract_address=acl_manager_address, admin_address=caller
        );
        let error_code = Errors.CALLER_NOT_POOL_ADMIN;
        with_attr error_message("{error_code}") {
            assert is_pool_admin = TRUE;
        }
        return ();
    }

    //
    // @dev Only pool can call functions marked by this modifier.
    //
    func assert_only_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller_address) = get_caller_address();
        let (pool) = IncentivizedERC20_pool.read();
        let error_code = Errors.CALLER_MUST_BE_POOL;
        with_attr error_message("{error_code}") {
            assert caller_address = pool;
        }
        return ();
    }

    // Getters

    func get_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        pool: felt
    ) {
        let (pool) = IncentivizedERC20_pool.read();
        return (pool,);
    }

    //
    // @notice Returns the address of the Incentives Controller contract
    // @return The address of the Incentives Controller
    //
    func get_incentives_controller{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (incentives_controller: felt) {
        let (incentives_controller) = IncentivizedERC20_incentives_controller.read();
        return (incentives_controller,);
    }

    func total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        total_supply: Uint256
    ) {
        let (total_supply: Uint256) = IncentivizedERC20_total_supply.read();
        return (total_supply,);
    }

    func get_user_state{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt
    ) -> (state: DataTypes.UserState) {
        let (state) = IncentivizedERC20_user_state.read(account);
        return (state,);
    }

    func balance_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt
    ) -> (balance: Uint256) {
        let (state) = IncentivizedERC20_user_state.read(account);
        let balance_256 = to_uint256(state.balance);
        return (balance_256,);
    }

    func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, spender: felt
    ) -> (remaining: Uint256) {
        let (remaining) = IncentivizedERC20_allowances.read(owner, spender);
        return (remaining,);
    }

    // Setters

    func set_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, balance: felt
    ) {
        let (old_user_state) = IncentivizedERC20_user_state.read(account);
        let new_user_state = DataTypes.UserState(balance, old_user_state.additional_data);
        IncentivizedERC20_user_state.write(account, new_user_state);
        return ();
    }

    func set_additional_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, additional_data: felt
    ) {
        let (old_user_state) = IncentivizedERC20_user_state.read(account);
        let new_user_state = DataTypes.UserState(old_user_state.balance, additional_data);
        IncentivizedERC20_user_state.write(account, new_user_state);

        return ();
    }

    func set_total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        total_supply: Uint256
    ) -> () {
        IncentivizedERC20_total_supply.write(total_supply);
        return ();
    }

    func set_incentives_controller{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        incentives_controller: felt
    ) {
        assert_only_pool_admin();
        _set_incentives_controller(incentives_controller);
        return ();
    }

    func set_user_state{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, user_state: DataTypes.UserState
    ) {
        IncentivizedERC20_user_state.write(account, user_state);
        return ();
    }

    //
    // Main functions
    //

    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        pool: felt, name: felt, symbol: felt, decimals: felt
    ) {
        ERC20.initializer(name=name, symbol=symbol, decimals=decimals);
        let (addresses_provider) = IPool.get_addresses_provider(contract_address=pool);
        IncentivizedERC20_addresses_provider.write(addresses_provider);
        IncentivizedERC20_pool.write(pool);

        return ();
    }

    func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        recipient: felt, amount: Uint256
    ) -> (success: felt) {
        alloc_locals;
        let (local caller_address) = get_caller_address();

        _transfer(caller_address, recipient, amount);

        return (TRUE,);
    }

    func transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt, recipient: felt, amount: Uint256
    ) -> (success: felt) {
        alloc_locals;
        let (local caller_address) = get_caller_address();
        let (allowance) = IncentivizedERC20_allowances.read(sender, caller_address);

        with_attr error_message("Caller does not have enough allowance") {
            let (new_allowance) = SafeUint256.sub_le(allowance, amount);
        }

        _approve(sender, caller_address, new_allowance);
        _transfer(sender, recipient, amount);

        return (TRUE,);
    }

    //
    // @notice Approve `spender` to use `amount` of `owner`s balance
    // @param spender The address approved for spending
    // @param amount The amount of tokens to approve spending of
    //
    func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        spender: felt, amount: Uint256
    ) {
        alloc_locals;
        let (local caller_address) = get_caller_address();

        _approve(caller_address, spender, amount);

        return ();
    }

    //
    // @notice Increases the allowance of spender to spend caller tokens
    // @param spender The user allowed to spend on behalf of caller
    // @param added_value The amount being added to the allowance
    // @return TRUE = 1
    //
    func increase_allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        spender: felt, added_value: Uint256
    ) -> (success: felt) {
        alloc_locals;
        let (caller_address) = get_caller_address();
        let (old_allowance) = IncentivizedERC20_allowances.read(caller_address, spender);

        with_attr error_message("Increased allowance overflows") {
            let (new_allowance) = SafeUint256.add(old_allowance, added_value);
        }

        _approve(caller_address, spender, new_allowance);

        return (TRUE,);
    }

    //
    // @notice Decreases the allowance of spender to spend caller tokens
    // @param spender The user allowed to spend on behalf of caller
    // @param subtracted_value The amount being subtracted to the allowance
    // @return TRUE = 1
    //
    func decrease_allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        spender: felt, subtracted_value: Uint256
    ) -> (success: felt) {
        alloc_locals;
        let (caller_address) = get_caller_address();
        let (old_allowance) = IncentivizedERC20_allowances.read(caller_address, spender);

        with_attr error_message("Decreased allowance overflow") {
            let (new_allowance) = SafeUint256.sub_le(old_allowance, subtracted_value);
        }

        _approve(caller_address, spender, new_allowance);

        return (TRUE,);
    }

    //
    // Internal
    //

    //
    // @notice Sets address of incentives controller as storage variable
    // @param incentives_controller The address of incentives controller
    //
    func _set_incentives_controller{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(incentives_controller: felt) -> () {
        IncentivizedERC20_incentives_controller.write(incentives_controller);
        return ();
    }

    //
    // @notice Transfers tokens between two users and apply incentives if defined.
    // @param sender The source address
    // @param recipient The destination address
    // @param amount The amount getting transferred
    // @dev the amount should be passed as uint128 according to solidity code. TODO: should it?
    //
    func _transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt, recipient: felt, amount: Uint256
    ) -> () {
        let error_code = Errors.ZERO_ADDRESS_NOT_VALID;
        with_attr error_message("{error_code}") {
            assert_not_zero(sender);
        }

        let amount_felt = to_felt(amount);

        let (sender_state) = IncentivizedERC20_user_state.read(sender);
        let old_sender_balance = sender_state.balance;
        let old_sender_balance_256 = to_uint256(old_sender_balance);
        with_attr error_message("Transfer amount exceeds balance") {
            assert_le_felt(amount_felt, old_sender_balance);
        }

        let new_sender_balance = old_sender_balance - amount_felt;

        let new_sender_state = DataTypes.UserState(
            new_sender_balance, sender_state.additional_data
        );
        IncentivizedERC20_user_state.write(sender, new_sender_state);

        let (recipient_state) = IncentivizedERC20_user_state.read(recipient);
        let recipient_balance = recipient_state.balance;
        let recipient_balance_256 = to_uint256(recipient_balance);
        let new_recipient_balance = recipient_balance + amount_felt;
        let new_recipient_state = DataTypes.UserState(
            new_recipient_balance, recipient_state.additional_data
        );
        IncentivizedERC20_user_state.write(recipient, new_recipient_state);

        Transfer.emit(sender, recipient, amount);

        let (incentives_controller) = IncentivizedERC20_incentives_controller.read();
        let incentives_controller_not_zero = is_not_zero(incentives_controller);

        let (total_supply) = IncentivizedERC20_total_supply.read();

        if (incentives_controller_not_zero == TRUE) {
            IAaveIncentivesController.handle_action(
                contract_address=incentives_controller,
                account=sender,
                user_balance=old_sender_balance_256,
                total_supply=total_supply,
            );
            let sender_not_the_recipient = is_not_zero(sender - recipient);
            if (sender_not_the_recipient == TRUE) {
                IAaveIncentivesController.handle_action(
                    contract_address=incentives_controller,
                    account=recipient,
                    user_balance=recipient_balance_256,
                    total_supply=total_supply,
                );
                return ();
            }
            return ();
        }
        return ();
    }

    //
    // @notice Approve `spender` to use `amount` of `owner`s balance
    // @param owner The address owning the tokens
    // @param spender The address approved for spending
    // @param amount The amount of tokens to approve spending of
    //
    func _approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, spender: felt, amount: Uint256
    ) -> () {
        IncentivizedERC20_allowances.write(owner, spender, amount);

        Approval.emit(owner, spender, amount);

        return ();
    }
}
