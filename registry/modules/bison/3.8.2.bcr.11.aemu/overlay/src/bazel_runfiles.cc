#include "rules_cc/cc/runfiles/runfiles.h"

#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <unistd.h>

using rules_cc::cc::runfiles::Runfiles;

struct BazelRunfiles {
    std::unique_ptr<Runfiles> ptr;
};

static std::string g_argv0;

static std::string resolve_execroot_path(const char *rel_execpath) {
    if (access(rel_execpath, F_OK) == 0) {
        char *real = realpath(rel_execpath, nullptr);
        if (real != nullptr) {
            std::string res(real);
            free(real);
            return res;
        }
    }
    if (!g_argv0.empty()) {
        size_t pos = g_argv0.find("/bazel-out/");
        if (pos != std::string::npos) {
            std::string candidate = g_argv0.substr(0, pos + 1) + rel_execpath;
            if (access(candidate.c_str(), F_OK) == 0) {
                char *real = realpath(candidate.c_str(), nullptr);
                if (real != nullptr) {
                    std::string res(real);
                    free(real);
                    return res;
                }
                return candidate;
            }
        }
    }
    return "";
}

extern "C" {

static struct BazelRunfiles *bazel_runfiles = NULL;

void bazel_runfiles_init(const char *argv0_cstr) {
    if (argv0_cstr != nullptr) {
        g_argv0 = argv0_cstr;
    }
    if (bazel_runfiles != nullptr) {
        return;
    }

    Runfiles *runfiles;
    std::string argv0(argv0_cstr ? argv0_cstr : "");
    std::string source_repository(BAZEL_CURRENT_REPOSITORY);
    std::string error;
    runfiles = Runfiles::Create(argv0, source_repository, &error);
    if (runfiles == nullptr) {
        return;
    }

    bazel_runfiles = new BazelRunfiles;
    bazel_runfiles->ptr.reset(runfiles);
}

char *bazel_runfiles_bison_pkgdatadir() {
    if (bazel_runfiles != nullptr) {
        std::string result = bazel_runfiles->ptr->Rlocation(M4SUGAR_RLOCATION);
        if (!result.empty() && access(result.c_str(), R_OK) == 0 && result.size() > 19) {
            char *datadir = strdup(result.c_str());
            datadir[result.size() - 19] = '\x00';
            return datadir;
        }
    }
    std::string fallback = resolve_execroot_path(M4SUGAR_EXECPATH);
    if (!fallback.empty() && fallback.size() > 19) {
        char *datadir = strdup(fallback.c_str());
        datadir[fallback.size() - 19] = '\x00';
        return datadir;
    }
    return nullptr;
}

char *bazel_runfiles_m4() {
    if (bazel_runfiles != nullptr) {
        std::string result = bazel_runfiles->ptr->Rlocation(M4_RLOCATION);
        if (!result.empty() && access(result.c_str(), X_OK) == 0) {
            return strdup(result.c_str());
        }
    }
    std::string fallback = resolve_execroot_path(M4_EXECPATH);
    if (!fallback.empty()) {
        return strdup(fallback.c_str());
    }
    return nullptr;
}

}
