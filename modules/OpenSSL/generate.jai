
#import "Basic";
#import "String";
#import "Bindings_Generator";
#import "Compiler";

#run {
    set_build_options_dc(.{do_output=false});

    options: Generate_Bindings_Options;
    using options;

    array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);

    array_add(*source_files, "/usr/include/openssl/safestack.h");
    array_add(*source_files, "/usr/include/openssl/conf.h");
    array_add(*source_files, "/usr/include/openssl/conf_api.h");
    array_add(*source_files, "/usr/include/openssl/lhash.h");
    array_add(*source_files, "/usr/include/openssl/bio.h");
    array_add(*source_files, "/usr/include/openssl/bioerr.h");
    array_add(*source_files, "/usr/include/openssl/x509.h");
    array_add(*source_files, "/usr/include/openssl/x509_vfy.h");
    array_add(*source_files, "/usr/include/openssl/x509err.h");
    array_add(*source_files, "/usr/include/openssl/x509v3.h");
    array_add(*source_files, "/usr/include/openssl/x509v3err.h");
    array_add(*source_files, "/usr/include/openssl/aes.h");
    array_add(*source_files, "/usr/include/openssl/asn1.h");
    array_add(*source_files, "/usr/include/openssl/asn1err.h");
    array_add(*source_files, "/usr/include/openssl/asn1t.h");
    array_add(*source_files, "/usr/include/openssl/async.h");
    array_add(*source_files, "/usr/include/openssl/asyncerr.h");
    array_add(*source_files, "/usr/include/openssl/blowfish.h");
    array_add(*source_files, "/usr/include/openssl/bn.h");
    array_add(*source_files, "/usr/include/openssl/bnerr.h");
    array_add(*source_files, "/usr/include/openssl/buffer.h");
    array_add(*source_files, "/usr/include/openssl/buffererr.h");
    array_add(*source_files, "/usr/include/openssl/camellia.h");
    array_add(*source_files, "/usr/include/openssl/cast.h");
    array_add(*source_files, "/usr/include/openssl/cmac.h");
    array_add(*source_files, "/usr/include/openssl/cms.h");
    array_add(*source_files, "/usr/include/openssl/cmserr.h");
    array_add(*source_files, "/usr/include/openssl/comp.h");
    array_add(*source_files, "/usr/include/openssl/comperr.h");
    array_add(*source_files, "/usr/include/openssl/conferr.h");
    array_add(*source_files, "/usr/include/openssl/crypto.h");
    array_add(*source_files, "/usr/include/openssl/cryptoerr.h");
    array_add(*source_files, "/usr/include/openssl/ct.h");
    array_add(*source_files, "/usr/include/openssl/cterr.h");
    array_add(*source_files, "/usr/include/openssl/des.h");
    array_add(*source_files, "/usr/include/openssl/dh.h");
    array_add(*source_files, "/usr/include/openssl/dherr.h");
    array_add(*source_files, "/usr/include/openssl/dsa.h");
    array_add(*source_files, "/usr/include/openssl/dsaerr.h");
    array_add(*source_files, "/usr/include/openssl/dtls1.h");
    array_add(*source_files, "/usr/include/openssl/e_os2.h");
    array_add(*source_files, "/usr/include/openssl/ebcdic.h");
    array_add(*source_files, "/usr/include/openssl/ec.h");
    array_add(*source_files, "/usr/include/openssl/ecdh.h");
    array_add(*source_files, "/usr/include/openssl/ecdsa.h");
    array_add(*source_files, "/usr/include/openssl/ecerr.h");
    array_add(*source_files, "/usr/include/openssl/engine.h");
    array_add(*source_files, "/usr/include/openssl/engineerr.h");
    array_add(*source_files, "/usr/include/openssl/err.h");
    array_add(*source_files, "/usr/include/openssl/evp.h");
    array_add(*source_files, "/usr/include/openssl/evperr.h");
    array_add(*source_files, "/usr/include/openssl/hmac.h");
    array_add(*source_files, "/usr/include/openssl/idea.h");
    array_add(*source_files, "/usr/include/openssl/kdf.h");
    array_add(*source_files, "/usr/include/openssl/kdferr.h");
    array_add(*source_files, "/usr/include/openssl/md2.h");
    array_add(*source_files, "/usr/include/openssl/md4.h");
    array_add(*source_files, "/usr/include/openssl/md5.h");
    array_add(*source_files, "/usr/include/openssl/mdc2.h");
    array_add(*source_files, "/usr/include/openssl/modes.h");
    array_add(*source_files, "/usr/include/openssl/obj_mac.h");
    array_add(*source_files, "/usr/include/openssl/objects.h");
    array_add(*source_files, "/usr/include/openssl/objectserr.h");
    array_add(*source_files, "/usr/include/openssl/ocsp.h");
    array_add(*source_files, "/usr/include/openssl/ocsperr.h");
    array_add(*source_files, "/usr/include/openssl/opensslv.h");
    array_add(*source_files, "/usr/include/openssl/ossl_typ.h");
    array_add(*source_files, "/usr/include/openssl/pem.h");
    array_add(*source_files, "/usr/include/openssl/pem2.h");
    array_add(*source_files, "/usr/include/openssl/pemerr.h");
    array_add(*source_files, "/usr/include/openssl/pkcs12.h");
    array_add(*source_files, "/usr/include/openssl/pkcs12err.h");
    array_add(*source_files, "/usr/include/openssl/pkcs7.h");
    array_add(*source_files, "/usr/include/openssl/pkcs7err.h");
    array_add(*source_files, "/usr/include/openssl/rand.h");
    array_add(*source_files, "/usr/include/openssl/rand_drbg.h");
    array_add(*source_files, "/usr/include/openssl/randerr.h");
    array_add(*source_files, "/usr/include/openssl/rc2.h");
    array_add(*source_files, "/usr/include/openssl/rc4.h");
    array_add(*source_files, "/usr/include/openssl/rc5.h");
    array_add(*source_files, "/usr/include/openssl/ripemd.h");
    array_add(*source_files, "/usr/include/openssl/rsa.h");
    array_add(*source_files, "/usr/include/openssl/rsaerr.h");
    array_add(*source_files, "/usr/include/openssl/seed.h");
    array_add(*source_files, "/usr/include/openssl/sha.h");
    array_add(*source_files, "/usr/include/openssl/srp.h");
    array_add(*source_files, "/usr/include/openssl/srtp.h");
    array_add(*source_files, "/usr/include/openssl/ssl.h");
    array_add(*source_files, "/usr/include/openssl/ssl2.h");
    array_add(*source_files, "/usr/include/openssl/ssl3.h");
    array_add(*source_files, "/usr/include/openssl/sslerr.h");
    array_add(*source_files, "/usr/include/openssl/stack.h");
    array_add(*source_files, "/usr/include/openssl/store.h");
    array_add(*source_files, "/usr/include/openssl/storeerr.h");
    array_add(*source_files, "/usr/include/openssl/symhacks.h");
    array_add(*source_files, "/usr/include/openssl/tls1.h");
    array_add(*source_files, "/usr/include/openssl/ts.h");
    array_add(*source_files, "/usr/include/openssl/tserr.h");
    array_add(*source_files, "/usr/include/openssl/txt_db.h");
    array_add(*source_files, "/usr/include/openssl/ui.h");
    array_add(*source_files, "/usr/include/openssl/uierr.h");
    array_add(*source_files, "/usr/include/openssl/whrlpool.h");

    array_add(*libnames,      "libssl");

    output_filename: string;
    #if OS == .LINUX {
        output_filename = "linux.jai";
    }

    generate_bindings(options, output_filename);
}

