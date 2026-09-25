/*
 * sm4.c
 *
 * SM4分组密码算法实现
 * 基于GmSSL库
 *
 * 参考标准: GM/T 0002-2012 / GB/T 32907-2016
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

#ifdef HAVE_GMSSL
#include <gmssl/sm4.h>
#include <gmssl/rand.h>
#include <gmssl/mem.h>

PG_FUNCTION_INFO_V1(sm4_encrypt);
PG_FUNCTION_INFO_V1(sm4_decrypt);
PG_FUNCTION_INFO_V1(sm4_generate_key);
PG_FUNCTION_INFO_V1(sm4_encrypt_ecb);
PG_FUNCTION_INFO_V1(sm4_decrypt_ecb);
PG_FUNCTION_INFO_V1(sm4_encrypt_gcm);
PG_FUNCTION_INFO_V1(sm4_decrypt_gcm);

/*
 * SM4 CBC模式加密
 *
 * 用法: sm4_encrypt(data bytea, key bytea, iv bytea) returns bytea
 */
Datum
sm4_encrypt(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *key;
    bytea *iv;
    uint8_t *ciphertext;
    size_t ciphertext_len;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1) || PG_ARGISNULL(2))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);
    key = PG_GETARG_BYTEA_PP(1);
    iv = PG_GETARG_BYTEA_PP(2);

    /* 检查密钥长度 */
    if (VARSIZE_ANY_EXHDR(key) != 16)
        ereport(ERROR,
                (errmsg("SM4密钥长度必须为16字节")));

    /* 检查IV长度 */
    if (VARSIZE_ANY_EXHDR(iv) != 16)
        ereport(ERROR,
                (errmsg("SM4 IV长度必须为16字节")));

    /* 计算密文长度 */
    ciphertext_len = VARSIZE_ANY_EXHDR(data);
    if (ciphertext_len % 16 != 0)
        ciphertext_len = ((ciphertext_len / 16) + 1) * 16;

    ciphertext = (uint8_t *) palloc(ciphertext_len + 16);

    SM4_KEY sm4_key;
    if (sm4_set_key(VARDATA_ANY(key), SM4_ENCRYPT, &sm4_key) != 1)
        ereport(ERROR,
                (errmsg("SM4密钥设置失败")));

    if (sm4_cbc_encrypt(&sm4_key, VARDATA_ANY(iv),
                        VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data),
                        ciphertext) != 1)
        ereport(ERROR,
                (errmsg("SM4加密失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + ciphertext_len);
    SET_VARSIZE(result, VARHDRSZ + ciphertext_len);
    memcpy(VARDATA(result), ciphertext, ciphertext_len);

    pfree(ciphertext);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM4 CBC模式解密
 *
 * 用法: sm4_decrypt(data bytea, key bytea, iv bytea) returns bytea
 */
Datum
sm4_decrypt(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *key;
    bytea *iv;
    uint8_t *plaintext;
    size_t plaintext_len;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1) || PG_ARGISNULL(2))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);
    key = PG_GETARG_BYTEA_PP(1);
    iv = PG_GETARG_BYTEA_PP(2);

    /* 检查密钥长度 */
    if (VARSIZE_ANY_EXHDR(key) != 16)
        ereport(ERROR,
                (errmsg("SM4密钥长度必须为16字节")));

    /* 检查IV长度 */
    if (VARSIZE_ANY_EXHDR(iv) != 16)
        ereport(ERROR,
                (errmsg("SM4 IV长度必须为16字节")));

    plaintext_len = VARSIZE_ANY_EXHDR(data);
    plaintext = (uint8_t *) palloc(plaintext_len);

    SM4_KEY sm4_key;
    if (sm4_set_key(VARDATA_ANY(key), SM4_DECRYPT, &sm4_key) != 1)
        ereport(ERROR,
                (errmsg("SM4密钥设置失败")));

    if (sm4_cbc_decrypt(&sm4_key, VARDATA_ANY(iv),
                        VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data),
                        plaintext) != 1)
        ereport(ERROR,
                (errmsg("SM4解密失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + plaintext_len);
    SET_VARSIZE(result, VARHDRSZ + plaintext_len);
    memcpy(VARDATA(result), plaintext, plaintext_len);

    pfree(plaintext);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM4密钥生成
 *
 * 用法: sm4_generate_key() returns bytea
 */
Datum
sm4_generate_key(PG_FUNCTION_ARGS)
{
    uint8_t key[16];

    if (sm4_rand(key) != 1)
        ereport(ERROR,
                (errmsg("SM4密钥生成失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + 16);
    SET_VARSIZE(result, VARHDRSZ + 16);
    memcpy(VARDATA(result), key, 16);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM4 ECB模式加密
 *
 * 用法: sm4_encrypt_ecb(data bytea, key bytea) returns bytea
 */
Datum
sm4_encrypt_ecb(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *key;
    uint8_t *ciphertext;
    size_t ciphertext_len;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);
    key = PG_GETARG_BYTEA_PP(1);

    if (VARSIZE_ANY_EXHDR(key) != 16)
        ereport(ERROR,
                (errmsg("SM4密钥长度必须为16字节")));

    ciphertext_len = VARSIZE_ANY_EXHDR(data);
    if (ciphertext_len % 16 != 0)
        ciphertext_len = ((ciphertext_len / 16) + 1) * 16;

    ciphertext = (uint8_t *) palloc(ciphertext_len);

    SM4_KEY sm4_key;
    if (sm4_set_key(VARDATA_ANY(key), SM4_ENCRYPT, &sm4_key) != 1)
        ereport(ERROR,
                (errmsg("SM4密钥设置失败")));

    if (sm4_ecb_encrypt(&sm4_key,
                        VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data),
                        ciphertext) != 1)
        ereport(ERROR,
                (errmsg("SM4 ECB加密失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + ciphertext_len);
    SET_VARSIZE(result, VARHDRSZ + ciphertext_len);
    memcpy(VARDATA(result), ciphertext, ciphertext_len);

    pfree(ciphertext);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM4 ECB模式解密
 *
 * 用法: sm4_decrypt_ecb(data bytea, key bytea) returns bytea
 */
Datum
sm4_decrypt_ecb(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *key;
    uint8_t *plaintext;
    size_t plaintext_len;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);
    key = PG_GETARG_BYTEA_PP(1);

    if (VARSIZE_ANY_EXHDR(key) != 16)
        ereport(ERROR,
                (errmsg("SM4密钥长度必须为16字节")));

    plaintext_len = VARSIZE_ANY_EXHDR(data);
    plaintext = (uint8_t *) palloc(plaintext_len);

    SM4_KEY sm4_key;
    if (sm4_set_key(VARDATA_ANY(key), SM4_DECRYPT, &sm4_key) != 1)
        ereport(ERROR,
                (errmsg("SM4密钥设置失败")));

    if (sm4_ecb_decrypt(&sm4_key,
                        VARDATA_ANY(data), VARSIZE_ANY_EXHDR(data),
                        plaintext) != 1)
        ereport(ERROR,
                (errmsg("SM4 ECB解密失败")));

    bytea *result = (bytea *) palloc(VARHDRSZ + plaintext_len);
    SET_VARSIZE(result, VARHDRSZ + plaintext_len);
    memcpy(VARDATA(result), plaintext, plaintext_len);

    pfree(plaintext);

    PG_RETURN_BYTEA_P(result);
}

/*
 * SM4 GCM模式加密（带认证）
 *
 * 用法: sm4_encrypt_gcm(data bytea, key bytea, iv bytea, aad bytea) returns bytea
 */
Datum
sm4_encrypt_gcm(PG_FUNCTION_ARGS)
{
    bytea *data;
    bytea *key;
    bytea *iv;
    bytea *aad;
    uint8_t *ciphertext;
    uint8_t tag[16];
    size_t ciphertext_len;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1) || PG_ARGISNULL(2))
        PG_RETURN_NULL();

    data = PG_GETARG_BYTEA_PP(0);
    key = PG_GETARG_BYTEA_PP(1);
    iv = PG_GETARG_BYTEA_PP(2);
    aad = PG_GETARG_BYTEA_PP(3);

    if (VARSIZE_ANY_EXHDR(key) != 16)
        ereport(ERROR,
                (errmsg("SM4密钥长度必须为16字节")));

    ciphertext_len = VARSIZE_ANY_EXHDR(data);
    ciphertext = (uint8_t *) palloc(ciphertext_len);

    /* TODO: 实现SM4-GCM加密 */
    ereport(ERROR,
            (errmsg("SM4-GCM模式暂未实现")));

    PG_RETURN_NULL();
}

/*
 * SM4 GCM模式解密（带认证）
 *
 * 用法: sm4_decrypt_gcm(data bytea, key bytea, iv bytea, aad bytea, tag bytea) returns bytea
 */
Datum
sm4_decrypt_gcm(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4-GCM模式暂未实现")));
    PG_RETURN_NULL();
}

#else /* !HAVE_GMSSL */

/*
 * 未启用GmSSL时的桩函数
 */
Datum
sm4_encrypt(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm4_decrypt(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm4_generate_key(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm4_encrypt_ecb(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm4_decrypt_ecb(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm4_encrypt_gcm(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

Datum
sm4_decrypt_gcm(PG_FUNCTION_ARGS)
{
    ereport(ERROR,
            (errmsg("SM4算法需要GmSSL支持")));
    PG_RETURN_NULL();
}

#endif /* HAVE_GMSSL */
