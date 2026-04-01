/*
 * NNG SDK QEMU ARM64 Harness
 *
 * Loads liblib_nng_sdk.so under QEMU user-mode emulation, calls JNI_OnLoad
 * and nng_Core_Initialize, then resolves NFTP tokens via ifapi.
 *
 * RunLoop is NOT called — it crashes with a thread_server assertion.
 * The .xs scripts are compiled during Initialize but can't execute without RunLoop.
 *
 * Build:
 *   NDK=/path/to/ndk
 *   $NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang \
 *     -o harness harness.c -ldl -Wl,-rpath,/data/libs
 *
 * Run:
 *   qemu-aarch64-static -L /tmp/qemu_android \
 *     -E LD_LIBRARY_PATH=/data/libs:/system/lib64 \
 *     /tmp/qemu_android/data/harness /data/xs_extract/data
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
#include <signal.h>
#include <ucontext.h>

typedef int (*fn_void_ret_int)(void);
typedef int (*fn_ptr_ret_int)(void *);
typedef void (*fn_3ptr)(void *, void *, void *);
typedef void *(*fn_JNI_OnLoad)(void *vm, void *reserved);
typedef int (*fn_token_from_id)(const char *name);

/* Minimal JNI stubs — just enough for JNI_OnLoad to cache field IDs */
static char fake_objs[16][256];
static int fake_obj_idx = 0;
static long fake_id_counter = 0x1000;
static void *alloc_fake(void) { return fake_objs[fake_obj_idx++ % 16]; }
static const char *root_path = "";
static int jni_GetVersion(void *e) { return 0x10006; }
static void *jni_FindClass(void *e, const char *n) { return alloc_fake(); }
static void *jni_NewGlobalRef(void *e, void *o) { return o ? o : alloc_fake(); }
static void jni_noop() {}
static long jni_GetFieldID(void *e, void *c, const char *n, const char *s) { return ++fake_id_counter; }
static long jni_GetMethodID(void *e, void *c, const char *n, const char *s) { return ++fake_id_counter; }
static void *jni_GetObjectField(void *e, void *o, long f) { return NULL; }
static int jni_GetIntField(void *e, void *o, long f) { return 0; }
static void *jni_GetStaticObjectField(void *e, void *c, long f) { return alloc_fake(); }
static const char *jni_GetStringUTFChars(void *e, void *s, void *c) { return root_path; }
static int jni_RegisterNatives(void *e, void *c, void *m, int n) { return 0; }
static int jni_GetJavaVM(void *e, void **vm) { return 0; }
static int jni_IsSameObject(void *e, void *a, void *b) { return a == b; }
static void *jni_NewObject(void *e, void *c, long m, ...) { return alloc_fake(); }
static void *jni_default(void) { return NULL; }
static void *jni_functions[256];
static void *jni_env_ptr;
static void *jvm_functions[16];
static void *jvm_ptr;
static int jvm_GetEnv(void *vm, void **env, int ver) { *env = &jni_env_ptr; return 0; }

static void setup_jni(void) {
    for (int i = 0; i < 256; i++) jni_functions[i] = jni_default;
    jni_functions[4]=jni_GetVersion; jni_functions[6]=jni_FindClass;
    jni_functions[17]=jni_default; jni_functions[18]=jni_noop; jni_functions[19]=jni_noop;
    jni_functions[21]=jni_NewGlobalRef; jni_functions[22]=jni_noop; jni_functions[23]=jni_noop;
    jni_functions[24]=jni_IsSameObject; jni_functions[28]=jni_NewObject;
    jni_functions[31]=jni_FindClass; jni_functions[33]=jni_GetMethodID;
    jni_functions[34]=jni_default; jni_functions[37]=jni_default;
    jni_functions[49]=jni_default; jni_functions[61]=jni_noop;
    jni_functions[67]=jni_GetFieldID; jni_functions[95]=jni_GetObjectField;
    jni_functions[96]=jni_default; jni_functions[100]=jni_GetIntField;
    jni_functions[101]=jni_default; jni_functions[113]=jni_GetMethodID;
    jni_functions[114]=jni_default; jni_functions[141]=jni_noop;
    jni_functions[144]=jni_GetFieldID; jni_functions[145]=jni_GetStaticObjectField;
    jni_functions[154]=jni_RegisterNatives; jni_functions[167]=jni_NewObject;
    jni_functions[168]=jni_default; jni_functions[169]=jni_GetStringUTFChars;
    jni_functions[170]=jni_noop; jni_functions[171]=jni_default;
    jni_functions[173]=jni_default; jni_functions[222]=jni_default;
    jni_functions[228]=jni_GetJavaVM;
    jni_env_ptr = jni_functions;
    memset(jvm_functions, 0, sizeof(jvm_functions));
    jvm_functions[4]=jvm_GetEnv; jvm_functions[6]=jvm_GetEnv;
    jvm_ptr = jvm_functions;
}

static void *sdk_handle = NULL;

static void crash_handler(int sig, siginfo_t *info, void *ctx) {
    ucontext_t *uc = (ucontext_t *)ctx;
    unsigned long long pc = uc->uc_mcontext.pc;
    fn_ptr_ret_int ci = dlsym(sdk_handle, "nng_Core_Initialize");
    unsigned long long base = (unsigned long long)ci - 0xba3cd0;
    fprintf(stderr, "\n[CRASH] sig=%d addr=%p PC=SDK+0x%llx LR=SDK+0x%llx\n",
            sig, info->si_addr, pc - base, uc->uc_mcontext.regs[30] - base);
    fflush(stderr);
    _exit(99);
}

int main(int argc, char **argv) {
    const char *xs_dir = argc > 1 ? argv[1] : "/data/xs_extract/data";
    char path[512];
    snprintf(path, sizeof(path), "%s/yellowbox", xs_dir);
    root_path = path;

    printf("[*] NNG SDK QEMU Harness\n");
    setup_jni();

    sdk_handle = dlopen("liblib_nng_sdk.so", RTLD_NOW);
    if (!sdk_handle) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
    printf("[+] SDK loaded\n");

    struct sigaction sa = { .sa_sigaction = crash_handler, .sa_flags = SA_SIGINFO | SA_RESETHAND };
    sigemptyset(&sa.sa_mask);

    fn_JNI_OnLoad onload = dlsym(sdk_handle, "JNI_OnLoad");
    if (onload) { onload(&jvm_ptr, NULL); printf("[+] JNI_OnLoad OK\n"); }
    sigaction(SIGSEGV, &sa, NULL); sigaction(SIGABRT, &sa, NULL); sigaction(SIGILL, &sa, NULL);

    fn_3ptr set_root = dlsym(sdk_handle, "Java_com_nng_core_SDK_SetRootPathNative");
    if (set_root) { set_root(&jni_env_ptr, NULL, alloc_fake()); printf("[+] SetRootPathNative OK\n"); }

    fn_void_ret_int core_test = dlsym(sdk_handle, "nng_Core_EnableTesting");
    if (core_test) core_test();

    fn_ptr_ret_int core_init = dlsym(sdk_handle, "nng_Core_Initialize");
    char config[292]; memset(config, 0, sizeof(config)); *(long *)config = 0x124;
    int ret = core_init(config);
    printf("[+] nng_Core_Initialize returned: %d\n", ret);

    sigaction(SIGSEGV, &sa, NULL); sigaction(SIGABRT, &sa, NULL); sigaction(SIGILL, &sa, NULL);

    /* Resolve NFTP tokens */
    fn_token_from_id tok = dlsym(sdk_handle, "ifapi_token_from_identifier");
    if (tok) {
        const char *names[] = {
            "device", "brand", "fileMapping", "diskInfo", "ls",
            "nftp", "queryInfo", "checkSum", "getFile", "pushFile",
            "deleteFile", "renameFile", "mkdir", "chmod",
            "prepareForTransfer", "transferFinished",
            "compact", "name", "size", "error", "path", "children",
            "md5", "sha1", "init", "fields",
            NULL
        };
        printf("\n[*] NFTP token resolution:\n");
        for (int i = 0; names[i]; i++) {
            int id = tok(names[i]);
            printf("    @%-25s = %d\n", names[i], id);
        }
    }

    printf("\n[+] Done. Engine initialized (no RunLoop).\n");
    return 0;
}
