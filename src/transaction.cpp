// Copyright (c) 2009-2010 Satoshi Nakamoto
// Copyright (c) 2009-2016 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "transaction.h"
//#include "script/interpreter.h"
#include "deps/sparkmobile/bitcoin/hash.h"
#include "deps/sparkmobile/bitcoin/tinyformat.h"
#include "deps/sparkmobile/bitcoin/utilstrencodings.h"

std::string COutPoint::ToString() const
{
    return strprintf("COutPoint(%s, %u)", hash.ToString(), n);
}

std::string COutPoint::ToStringShort() const
{
    return strprintf("COutPoint(%s, %u)", hash.ToString().substr(0,64), n);
}

CTxIn::CTxIn(COutPoint prevoutIn, CScript scriptSigIn, uint32_t nSequenceIn)
{
    prevout = prevoutIn;
    scriptSig = scriptSigIn;
    nSequence = nSequenceIn;
}

CTxIn::CTxIn(uint256 hashPrevTx, uint32_t nOut, CScript scriptSigIn, uint32_t nSequenceIn)
{
    prevout = COutPoint(hashPrevTx, nOut);
    scriptSig = scriptSigIn;
    nSequence = nSequenceIn;
}

bool CTxIn::IsZerocoinSpend() const
{
    return (prevout.IsNull() && scriptSig.size() > 0 && (scriptSig[0] == OP_ZEROCOINSPEND) );
}

bool CTxIn::IsSigmaSpend() const
{
    return (prevout.IsSigmaMintGroup() && scriptSig.size() > 0 && (scriptSig[0] == OP_SIGMASPEND) );
}

bool CTxIn::IsLelantusJoinSplit() const
{
    return (prevout.IsNull() && scriptSig.size() > 0 && (scriptSig[0] == OP_LELANTUSJOINSPLIT || scriptSig[0] == OP_LELANTUSJOINSPLITPAYLOAD) );
}

bool CTxIn::IsZerocoinRemint() const
{
    return (prevout.IsNull() && scriptSig.size() > 0 && (scriptSig[0] == OP_ZEROCOINTOSIGMAREMINT));
}

std::string CTxIn::ToString() const
{
    std::string str;
    str += "CTxIn(";
    str += prevout.ToString();
    if (prevout.IsNull())
        str += strprintf(", coinbase %s", HexStr(scriptSig).substr(0, 24));
    else
        str += strprintf(", scriptSig=%s", HexStr(scriptSig).substr(0, 24));
    if (nSequence != SEQUENCE_FINAL)
        str += strprintf(", nSequence=%u", nSequence);
    str += ")";
    return str;
}

CTxOut::CTxOut(const CAmount& nValueIn, CScript scriptPubKeyIn)
{
    nValue = nValueIn;
    scriptPubKey = scriptPubKeyIn;
}

std::string CTxOut::ToString() const
{
    return strprintf("CTxOut(nValue=%d.%08d, scriptPubKey=%s)", nValue / COIN, nValue % COIN, HexStr(scriptPubKey).substr(0, 30));
}
