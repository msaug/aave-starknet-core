from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_le, uint256_lt

namespace SafeUint256Cmp {
    func le{range_check_ptr}(a: Uint256, b: Uint256) -> felt {
        uint256_check(a);
        uint256_check(b);
        let (res) = uint256_le(a, b);
        return res;
    }

    func lt{range_check_ptr}(a: Uint256, b: Uint256) -> felt {
        uint256_check(a);
        uint256_check(b);
        let (res) = uint256_lt(a, b);
        return res;
    }
}
