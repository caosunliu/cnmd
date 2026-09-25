/*
 * sm3.c
 *
 * SM3杂凑算法实现
 * 基于GmSSL库
 *
 * 参考标准: GM/T 0004-2012 / GB/T 32905-2016
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

#ifdef HAVE_GMSSL
#include <gmssl/sm3.h>
#include <gmssl/mem.h>

PG_FUNCTION_INFO_V1(sm3_hash);
PG_FUNCTION_INFO_V1(sm3_hmac);
PG_FUNCTION_INFO_V1(sm3_verify_hash);

/*
 * SM3哈希计算
 *
 * 用法: sm3_hash(data bytea) returns bytea
 *       sm3_hash(data text) returns bytea
 */
Datum
sm3_hash(PG_FUNCTION_ARGS)
{
    bytea *data;
    uint8_t hash[32];
    size_t hash_len = 32;

    if (PG_ARGISNULL(0))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);

    if (sm3_digest(VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data), hash) != 1)
        ereport(ERROR,
                (errmsg("SM3哈希计算失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + hash_len);
    SET_VARSIZE(result, VARHDRSZ + hash_len);
    memcpy(VARDATA(result), hash, hash_len);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM3 HMAC计算
 *
 * 用法: sm3_hmac(data bytea, key bytea) returns bytea
 */
Datum
sm3_hmac(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *key;
    uint8_t mac[32];
    size_t mac_len = 32;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);
    key = PG_GETARG_BYTEA_PP(1);

    if (sm3_hmac_sm3(VARDATA_ANY(key), VARSIZE_ANY_EXHDR(key),
                     VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data),
                     mac) != 1)
        ereport(ERROR,
                (errmsg("SM3 HMAC计算失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + mac_len);
    SET_VARSIZE(result, VARHDRSZ + mac_len);
    memcpy(VARDATA(result), mac, mac_len);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM3哈希验证
 *
 * 用法: sm3_verify_hash(data bytea, expected_hash bytea) returns boolean
 */
Datum
sm3_verify_hash(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *expected_hash;
    uint8_t hash[32];
    size_t hash_len = 32;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_BOOL(false);

    data = PG_GETARG_BYTEA_PP(0);
    expected_hash = PG_GETARG_BYTEA_PP(1);

    /* 检查期望的哈希长度 */
    if (VARSIZE_ANY_EXHDR(expected_hash) != hash_len)
        PG_RETURN_BOOL(false);

    if (sm3_digest(VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data), hash) != 1)
        ereport(ERROR,
                (errmsg("SM3哈希计算失败")));

    /* 比较哈希值 */
    bool result = (memcmp(hash, VARDATA_ANY(expected_hash), hash_len) == 0);

    PG_RETURN_BOOL(result);
}

#else /* !HAVE_GMSSL */

/*
 * 未启用GmSSL时的桩函数
 */
Datum
sm3_hash(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM3算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm3_hmac(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM3算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm3_verify_hash(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM3算法需要GmSSL支持")));
    PG_RETURN_BOOL(false);
}

#endif /* HAVE_GMSSL */
