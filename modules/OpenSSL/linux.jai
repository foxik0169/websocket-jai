// *NOT* generated. Bare minimum...

libssl :: #system_library "libssl";
libcrypto :: #system_library "libcrypto";

OPENSSL_INIT_ADD_ALL_CIPHERS     :: 0x00000004;
OPENSSL_INIT_ADD_ALL_DIGESTS     :: 0x00000008;
OPENSSL_INIT_LOAD_CONFIG         :: 0x00000040;

OPENSSL_INIT_LOAD_SSL_STRINGS    :: 0x00200000;
OPENSSL_INIT_LOAD_CRYPTO_STRINGS :: 0x00000002;

SSL_SENT_SHUTDOWN     :: 1;
SSL_RECEIVED_SHUTDOWN :: 2;

SSL_ERROR_WANT_READ   :: 2;
SSL_ERROR_WANT_WRITE  :: 3;
SSL_ERROR_ZERO_RETURN :: 6;

OPENSSL_init_crypto :: (opts: u64, settings: *void) -> s32 #foreign libcrypto;
OPENSSL_init_ssl :: (opts: u64, settings: *void) -> s32 #foreign libssl;

SSL_METHOD :: void;
SSL_CTX :: void;
SSL :: void;

TLS_client_method :: () -> *SSL_METHOD #foreign libssl;
SSL_CTX_new :: (meth: *SSL_METHOD) -> *SSL_CTX #foreign libssl;
SSL_new :: (ctx: *SSL_CTX) -> *SSL #foreign libssl;
SSL_set_fd :: (ssl: *SSL, fd: s32) -> s32 #foreign libssl;
SSL_connect :: (ssl: *SSL) -> s32 #foreign libssl;
SSL_write :: (ssl: *SSL, buf: *void, num: s32) -> s32 #foreign libssl;
SSL_read :: (ssl: *SSL, buf: *void, num: s32) -> s32 #foreign libssl;
SSL_set_shutdown :: (ssl: *SSL, mode: s32) #foreign libssl;
ERR_get_error :: () -> u64 #foreign libcrypto;
ERR_error_string :: (e: u64, buf: *u8) -> *u8 #foreign libcrypto;
SSL_shutdown :: (ssl: *SSL) -> s32 #foreign libssl;
SSL_free :: (ssl: *SSL) #foreign libssl;
SSL_get_error :: (ssl: *SSL, ret: s32) -> s32 #foreign libssl;

OpenSSL_add_all_algorithms :: inline () -> s32 {
    return OPENSSL_init_crypto(OPENSSL_INIT_ADD_ALL_CIPHERS
                               | OPENSSL_INIT_ADD_ALL_DIGESTS
                               | OPENSSL_INIT_LOAD_CONFIG, null);
}

SSL_load_error_strings :: inline () -> s32 {
    return OPENSSL_init_ssl(OPENSSL_INIT_LOAD_SSL_STRINGS
                            | OPENSSL_INIT_LOAD_CRYPTO_STRINGS, null);
}

SHA1 :: (data: *u8, count: u32, message_digest: *u8) -> *u8 #foreign libssl;

