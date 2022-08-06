# @version ^0.3.5
"""
@title Elliptic Curve Digital Signature Algorithm (ECDSA) Functions
@license GNU Affero General Public License v3.0
@author pcaversaccio
@notice These functions can be used to verify that a message was signed
        by the holder of the private key of a given address. The implementation
        is inspired by OpenZeppelin's implementation here:
        https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol.
"""


_MALLEABILITY_THRESHOLD: constant(bytes32) = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
_SIGNATURE_INCREMENT: constant(bytes32) = 0X7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF


@external
@pure
def recover_sig(hash: bytes32, signature: Bytes[65]) -> address:
    """
    @dev Recovers the signer address from a message digest `hash`
         and the signature `signature`.
    @param hash The 32-bytes message digest that was signed.
    @param signature The secp256k1 64/65-bytes signature of `hash`.
    @return address The recovered 20-bytes signer address.
    """
    # 65-bytes case: r,s,v standard signature.
    if (len(signature) == 65):
        r: uint256 = extract32(signature, 0, output_type=uint256)
        s: uint256 = extract32(signature, 32, output_type=uint256)
        v: uint256 = convert(slice(signature, 64, 1), uint256)
        return self._try_recover_vrs(hash, v, r, s)
    # 64-bytes case: r,vs signature; see: https://eips.ethereum.org/EIPS/eip-2098.
    elif (len(signature) == 64):
        r: uint256 = extract32(signature, 0, output_type=uint256)
        vs: uint256 = extract32(signature, 32, output_type=uint256)
        return self._try_recover_r_vs(hash, r, vs)
    else:
        return empty(address)


@internal
@pure
def _recover_vrs(hash: bytes32, v: uint256, r: uint256, s: uint256) -> address:
    """
    @dev Recovers the signer address from a message digest `hash`
         and the secp256k1 signature parameters `v`, `r`, and `s`.
    @param hash The 32-bytes message digest that was signed.
    @param v The secp256k1 1-byte signature parameter `v`.
    @param r The secp256k1 32-bytes signature parameter `r`.
    @param s The secp256k1 32-bytes signature parameter `s`.
    @return address The recovered 20-bytes signer address.
    """
    return self._try_recover_vrs(hash, v, r, s)


@internal
@pure
def _try_recover_r_vs(hash: bytes32, r: uint256, vs: uint256) -> address:
    """
    @dev Recovers the signer address from a message digest `hash`
         and the secp256k1 short signature fields `r` and `vs`.
    @notice See https://eips.ethereum.org/EIPS/eip-2098 for the
            compact signature representation.
    @param hash The 32-bytes message digest that was signed.
    @param r The secp256k1 32-bytes signature parameter `r`.
    @param vs The secp256k1 32-bytes short signature field of `v` and `s`.
    @return address The recovered 20-bytes signer address.
    """
    s: uint256 = vs & convert(_SIGNATURE_INCREMENT, uint256)
    # We do not check for an overflow here since the shift operation
    # `shift(vs, -255)` results essentially in a uint8 type (0 or 1)
    # and we use uint256 as result type.
    v: uint256 = unsafe_add(shift(vs, -255), 27)
    return self._try_recover_vrs(hash, v, r, s)


@internal
@pure
def _try_recover_vrs(hash: bytes32, v: uint256, r: uint256, s: uint256) -> address:
    """
    @dev Recovers the signer address from a message digest `hash`
         and the secp256k1 signature parameters `v`, `r`, and `s`.
    @notice All client implementations of the precompile `ecrecover`
            check if the value of `v` is 27 or 28. The references for
            the different client implementations can be found here:
            https://github.com/ethereum/yellowpaper/pull/860. Thus,
            the signature check on the value of `v` is neglected.
    @param hash The 32-bytes message digest that was signed.
    @param v The secp256k1 1-byte signature parameter `v`.
    @param r The secp256k1 32-bytes signature parameter `r`.
    @param s The secp256k1 32-bytes signature parameter `s`.
    @return address The recovered 20-bytes signer address.
    """
    if (s > convert(_MALLEABILITY_THRESHOLD, uint256)):
        raise "ECDSA: invalid signature 's' value"

    signer: address = ecrecover(hash, v, r, s)
    if (signer == empty(address)):
        raise "ECDSA: invalid signature"
    
    return signer


@external
@pure
def to_eth_signed_message_hash(hash: bytes32) -> bytes32:
    """
    @dev Returns an Ethereum signed message from a 32-bytes
         message digest `hash`.
    @notice This function returns a 32-bytes hash that
            corresponds to the one signed with the JSON-RPC method:
            https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sign.
            This method is part of EIP-191:
            https://eips.ethereum.org/EIPS/eip-191.
    @param hash The 32-bytes message digest.
    @return bytes32 The 32-bytes Ethereum signed message.
    """
    return keccak256(concat(b"\x19Ethereum Signed Message:\n32", hash))


@external
@pure
def to_typed_data_hash(domain_separator: bytes32, struct_hash: bytes32) -> bytes32:
    """
    @dev Returns an Ethereum signed typed data from a 32-bytes
         `domain_separator` and a 32-bytes `struct_hash`.
    @notice This function returns a 32-bytes hash that
            corresponds to the one signed with the JSON-RPC method:
            https://eips.ethereum.org/EIPS/eip-712#specification-of-the-eth_signtypeddata-json-rpc.
            This method is part of EIP-712:
            https://eips.ethereum.org/EIPS/eip-712.
    @param domain_separator The 32-bytes domain separator that is
           used as part of the EIP-712 encoding scheme.
    @param struct_hash The 32-bytes struct hash that is used as
           part of the EIP-712 encoding scheme. See the definition:
           https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    @return bytes32 The 32-bytes Ethereum signed typed data.
    """
    return keccak256(concat(b"\x19\x01", domain_separator, struct_hash))
