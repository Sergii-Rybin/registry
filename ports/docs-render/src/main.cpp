#include <inja/inja.hpp>
#include <nlohmann/json.hpp>

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <cerrno>
#include <csignal>
#include <fcntl.h>
#include <poll.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

import std;

namespace fs = std::filesystem;

namespace {

struct Options {
    fs::path template_path;
    fs::path output_path;
    std::vector<fs::path> in_place_paths;
    fs::path source_dir = ".";
    bool check_only = false;
    std::vector<std::pair<std::string, fs::path>> data_files;
    std::map<std::string, std::string> targets;
    std::string emulator;
    int timeout_seconds = 15;
};

[[nodiscard]] std::string normalize_lf(std::string_view input) {
    std::string out;
    out.reserve(input.size());
    for (std::size_t i = 0; i < input.size(); ++i) {
        if (input[i] == '\r') {
            if (i + 1 < input.size() && input[i + 1] == '\n') {
                ++i;
            }
            out.push_back('\n');
        } else {
            out.push_back(input[i]);
        }
    }
    return out;
}

[[nodiscard]] std::string read_file_binary(const fs::path& path) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) {
        throw std::runtime_error(std::format("Failed to open file for reading: {}", path.string()));
    }
    std::ostringstream oss;
    oss << ifs.rdbuf();
    if (!ifs && !ifs.eof()) {
        throw std::runtime_error(std::format("Failed to read file: {}", path.string()));
    }
    return oss.str();
}

void write_file_binary(const fs::path& path, std::string_view content) {
    if (path.has_parent_path()) {
        fs::create_directories(path.parent_path());
    }
    std::ofstream ofs(path, std::ios::binary | std::ios::trunc);
    if (!ofs) {
        throw std::runtime_error(std::format("Failed to open file for writing: {}", path.string()));
    }
    ofs.write(content.data(), static_cast<std::streamsize>(content.size()));
    if (!ofs) {
        throw std::runtime_error(std::format("Failed to write file: {}", path.string()));
    }
}

[[nodiscard]] std::string_view trim_whitespace(std::string_view sv) {
    constexpr std::string_view ws = " \t\r\n";
    const auto first = sv.find_first_not_of(ws);
    if (first == std::string_view::npos) {
        return {};
    }
    const auto last = sv.find_last_not_of(ws);
    return sv.substr(first, last - first + 1);
}

[[nodiscard]] std::string rtrim_whitespace(std::string s) {
    while (!s.empty() && (s.back() == ' ' || s.back() == '\t' || s.back() == '\r' || s.back() == '\n')) {
        s.pop_back();
    }
    return s;
}

[[nodiscard]] std::vector<std::string> split_lines(std::string_view text) {
    std::vector<std::string> lines;
    std::size_t pos = 0;
    while (pos < text.size()) {
        const auto nl = text.find('\n', pos);
        if (nl == std::string_view::npos) {
            lines.emplace_back(text.substr(pos));
            break;
        }
        lines.emplace_back(text.substr(pos, nl - pos));
        pos = nl + 1;
    }
    return lines;
}

[[nodiscard]] std::vector<std::string> split_command_tokens(std::string_view cmd) {
    std::vector<std::string> tokens;
    std::size_t i = 0;
    while (i < cmd.size()) {
        while (i < cmd.size() && (cmd[i] == ' ' || cmd[i] == '\t')) {
            ++i;
        }
        if (i >= cmd.size()) {
            break;
        }
        const auto start = i;
        while (i < cmd.size() && cmd[i] != ' ' && cmd[i] != '\t') {
            ++i;
        }
        tokens.emplace_back(cmd.substr(start, i - start));
    }
    return tokens;
}

[[nodiscard]] fs::path resolve_input_path(const fs::path& p, const fs::path& source_dir) {
    if (p.is_absolute() || fs::exists(p)) {
        return p;
    }
    return source_dir / p;
}

[[nodiscard]] fs::path resolve_output_path(const fs::path& p, const fs::path& source_dir) {
    if (p.is_absolute()) {
        return p;
    }
    return source_dir / p;
}

[[nodiscard]] std::string extract_snippet(
    const fs::path& source_dir,
    std::string_view rel_path,
    std::optional<std::string_view> region
) {
    const fs::path full_path = source_dir / fs::path(rel_path);
    const std::string content = normalize_lf(read_file_binary(full_path));
    const std::vector<std::string> all_lines = split_lines(content);

    std::vector<std::string> selected;
    if (region.has_value() && !region->empty()) {
        const std::string start_marker = std::format("// [snippet:{}]", *region);
        const std::string end_marker = std::format("// [end:{}]", *region);
        bool found_start = false;
        bool found_end = false;
        for (const auto& line : all_lines) {
            const auto trimmed = trim_whitespace(line);
            if (!found_start) {
                if (trimmed == start_marker) {
                    found_start = true;
                }
                continue;
            }
            if (trimmed == end_marker) {
                found_end = true;
                break;
            }
            selected.push_back(line);
        }
        if (!found_start) {
            throw std::runtime_error(
                std::format("Snippet start marker '{}' not found in {}", start_marker, full_path.string())
            );
        }
        if (!found_end) {
            throw std::runtime_error(
                std::format("Snippet end marker '{}' not found in {}", end_marker, full_path.string())
            );
        }
    } else {
        selected = all_lines;
    }

    std::vector<std::string> filtered;
    filtered.reserve(selected.size());
    bool in_hide_block = false;
    for (const auto& line : selected) {
        const auto trimmed = trim_whitespace(line);
        if (in_hide_block) {
            if (trimmed == "// [end-hide]") {
                in_hide_block = false;
            }
            continue;
        }
        if (trimmed == "// [hide]") {
            in_hide_block = true;
            continue;
        }
        if (line.find("// [hide]") != std::string::npos) {
            continue;
        }
        filtered.push_back(line);
    }

    if (in_hide_block) {
        throw std::runtime_error(std::format("Unclosed // [hide] block in {}", full_path.string()));
    }

    std::size_t min_indent = std::numeric_limits<std::size_t>::max();
    for (const auto& line : filtered) {
        if (trim_whitespace(line).empty()) {
            continue;
        }
        std::size_t indent = 0;
        while (indent < line.size() && line[indent] == ' ') {
            ++indent;
        }
        min_indent = std::min(min_indent, indent);
    }
    if (min_indent == std::numeric_limits<std::size_t>::max()) {
        min_indent = 0;
    }

    std::string result;
    for (std::size_t i = 0; i < filtered.size(); ++i) {
        if (i > 0) {
            result.push_back('\n');
        }
        if (trim_whitespace(filtered[i]).empty()) {
            continue;
        }
        result.append(filtered[i], min_indent, std::string::npos);
    }
    return result;
}

#ifdef _WIN32

[[nodiscard]] std::string quote_win_arg(std::string_view arg) {
    if (!arg.empty() && arg.find_first_of(" \t\"") == std::string_view::npos) {
        return std::string(arg);
    }
    std::string out = "\"";
    for (char c : arg) {
        if (c == '"') {
            out += "\\\"";
        } else {
            out.push_back(c);
        }
    }
    out.push_back('"');
    return out;
}

[[nodiscard]] std::string run_process(const std::vector<std::string>& argv, int timeout_seconds) {
    SECURITY_ATTRIBUTES sa{};
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;

    HANDLE stdout_read = nullptr;
    HANDLE stdout_write = nullptr;
    if (!CreatePipe(&stdout_read, &stdout_write, &sa, 0)) {
        throw std::runtime_error("CreatePipe failed");
    }
    SetHandleInformation(stdout_read, HANDLE_FLAG_INHERIT, 0);

    std::string cmdline;
    for (std::size_t i = 0; i < argv.size(); ++i) {
        if (i > 0) {
            cmdline.push_back(' ');
        }
        cmdline += quote_win_arg(argv[i]);
    }

    STARTUPINFOA si{};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = stdout_write;
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

    PROCESS_INFORMATION pi{};
    if (!CreateProcessA(
            nullptr,
            cmdline.data(),
            nullptr,
            nullptr,
            TRUE,
            0,
            nullptr,
            nullptr,
            &si,
            &pi
        )) {
        CloseHandle(stdout_read);
        CloseHandle(stdout_write);
        throw std::runtime_error(std::format("Failed to launch process: {}", cmdline));
    }
    CloseHandle(stdout_write);

    std::string output;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(timeout_seconds);
    char buf[4096];
    for (;;) {
        DWORD avail = 0;
        if (PeekNamedPipe(stdout_read, nullptr, 0, nullptr, &avail, nullptr) && avail > 0) {
            DWORD bytes_read = 0;
            if (ReadFile(stdout_read, buf, sizeof(buf), &bytes_read, nullptr) && bytes_read > 0) {
                output.append(buf, bytes_read);
            }
            continue;
        }
        const DWORD wait_rc = WaitForSingleObject(pi.hProcess, 10);
        if (wait_rc == WAIT_OBJECT_0) {
            DWORD bytes_read = 0;
            while (ReadFile(stdout_read, buf, sizeof(buf), &bytes_read, nullptr) && bytes_read > 0) {
                output.append(buf, bytes_read);
            }
            break;
        }
        if (std::chrono::steady_clock::now() >= deadline) {
            TerminateProcess(pi.hProcess, 1);
            WaitForSingleObject(pi.hProcess, 1000);
            CloseHandle(stdout_read);
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
            throw std::runtime_error(std::format("Process timed out after {}s: {}", timeout_seconds, argv[0]));
        }
    }

    DWORD exit_code = 0;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(stdout_read);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    if (exit_code != 0) {
        throw std::runtime_error(std::format("Process exited with code {}: {}", exit_code, argv[0]));
    }
    return rtrim_whitespace(normalize_lf(output));
}

#else

[[nodiscard]] std::string run_process(const std::vector<std::string>& argv, int timeout_seconds) {
    int out_pipe[2]{-1, -1};
    int err_pipe[2]{-1, -1};
    if (pipe(out_pipe) != 0) {
        throw std::runtime_error(std::format("pipe() failed: {}", std::strerror(errno)));
    }
    if (pipe(err_pipe) != 0) {
        const int err = errno;
        close(out_pipe[0]);
        close(out_pipe[1]);
        throw std::runtime_error(std::format("pipe() failed: {}", std::strerror(err)));
    }

    const pid_t pid = fork();
    if (pid < 0) {
        const int err = errno;
        close(out_pipe[0]);
        close(out_pipe[1]);
        close(err_pipe[0]);
        close(err_pipe[1]);
        throw std::runtime_error(std::format("fork() failed: {}", std::strerror(err)));
    }

    if (pid == 0) {
        dup2(out_pipe[1], STDOUT_FILENO);
        dup2(err_pipe[1], STDERR_FILENO);
        close(out_pipe[0]);
        close(out_pipe[1]);
        close(err_pipe[0]);
        close(err_pipe[1]);

        std::vector<char*> c_argv;
        c_argv.reserve(argv.size() + 1);
        for (const auto& arg : argv) {
            c_argv.push_back(const_cast<char*>(arg.c_str()));
        }
        c_argv.push_back(nullptr);

        execvp(c_argv[0], c_argv.data());
        _exit(127);
    }

    close(out_pipe[1]);
    close(err_pipe[1]);

    fcntl(out_pipe[0], F_SETFL, O_NONBLOCK);
    fcntl(err_pipe[0], F_SETFL, O_NONBLOCK);

    std::string stdout_str;
    std::string stderr_str;
    bool out_open = true;
    bool err_open = true;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(timeout_seconds);

    char buf[4096];
    while (out_open || err_open) {
        const auto now = std::chrono::steady_clock::now();
        if (now >= deadline) {
            kill(pid, SIGKILL);
            int status = 0;
            waitpid(pid, &status, 0);
            close(out_pipe[0]);
            close(err_pipe[0]);
            throw std::runtime_error(std::format("Process timed out after {}s: {}", timeout_seconds, argv[0]));
        }

        const auto remaining_ms = std::chrono::duration_cast<std::chrono::milliseconds>(deadline - now).count();
        struct pollfd fds[2]{};
        nfds_t nfds = 0;
        if (out_open) {
            fds[nfds].fd = out_pipe[0];
            fds[nfds].events = POLLIN;
            ++nfds;
        }
        if (err_open) {
            fds[nfds].fd = err_pipe[0];
            fds[nfds].events = POLLIN;
            ++nfds;
        }

        const int rc = poll(fds, nfds, static_cast<int>(std::min<long long>(remaining_ms, 100)));
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            break;
        }

        for (nfds_t i = 0; i < nfds; ++i) {
            if ((fds[i].revents & (POLLIN | POLLHUP | POLLERR)) == 0) {
                continue;
            }
            const bool is_out = (fds[i].fd == out_pipe[0]);
            for (;;) {
                const ssize_t n = read(fds[i].fd, buf, sizeof(buf));
                if (n > 0) {
                    if (is_out) {
                        stdout_str.append(buf, static_cast<std::size_t>(n));
                    } else {
                        stderr_str.append(buf, static_cast<std::size_t>(n));
                    }
                } else if (n == 0) {
                    if (is_out) {
                        out_open = false;
                    } else {
                        err_open = false;
                    }
                    break;
                } else {
                    if (errno == EAGAIN || errno == EWOULDBLOCK) {
                        break;
                    }
                    if (is_out) {
                        out_open = false;
                    } else {
                        err_open = false;
                    }
                    break;
                }
            }
        }
    }

    close(out_pipe[0]);
    close(err_pipe[0]);

    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }

    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        std::string msg = std::format("Process failed ({})", argv[0]);
        if (WIFEXITED(status)) {
            msg += std::format(" with exit code {}", WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            msg += std::format(" terminated by signal {}", WTERMSIG(status));
        }
        const auto err_trimmed = rtrim_whitespace(normalize_lf(stderr_str));
        if (!err_trimmed.empty()) {
            msg += std::format(": {}", err_trimmed);
        }
        throw std::runtime_error(msg);
    }

    return rtrim_whitespace(normalize_lf(stdout_str));
}

#endif

struct InPlaceMarker {
    std::string lang;
    std::string expr;
};

[[nodiscard]] std::optional<InPlaceMarker> parse_in_place_marker(std::string_view line) {
    const auto trimmed = trim_whitespace(line);
    constexpr std::string_view prefix = "<!-- inja";
    constexpr std::string_view suffix = "-->";
    if (!trimmed.starts_with(prefix) || !trimmed.ends_with(suffix)) {
        return std::nullopt;
    }

    std::string_view rest = trimmed.substr(prefix.size(), trimmed.size() - prefix.size() - suffix.size());
    if (rest.starts_with(':')) {
        return InPlaceMarker{
            .lang = {},
            .expr = std::string(trim_whitespace(rest.substr(1))),
        };
    }

    if (rest.starts_with('(')) {
        const auto close_paren = rest.find("):");
        if (close_paren == std::string_view::npos) {
            return std::nullopt;
        }
        return InPlaceMarker{
            .lang = std::string(trim_whitespace(rest.substr(1, close_paren - 1))),
            .expr = std::string(trim_whitespace(rest.substr(close_paren + 2))),
        };
    }

    return std::nullopt;
}

[[nodiscard]] std::string render_in_place_content(
    std::string_view normalized_content,
    const fs::path& file_path,
    inja::Environment& env,
    const nlohmann::json& data
) {
    const bool trailing_nl = !normalized_content.empty() && normalized_content.back() == '\n';
    const std::vector<std::string> lines = split_lines(normalized_content);

    std::vector<std::string> out_lines;
    out_lines.reserve(lines.size());

    for (std::size_t i = 0; i < lines.size(); ++i) {
        const auto marker = parse_in_place_marker(lines[i]);
        if (!marker.has_value()) {
            out_lines.push_back(lines[i]);
            continue;
        }

        out_lines.push_back(lines[i]);

        std::size_t end_idx = i + 1;
        while (end_idx < lines.size() && trim_whitespace(lines[end_idx]) != "<!-- end-inja -->") {
            ++end_idx;
        }
        if (end_idx >= lines.size()) {
            throw std::runtime_error(
                std::format("Unclosed inja block starting at line {} in {}", i + 1, file_path.string())
            );
        }

        const std::string rendered = normalize_lf(env.render(marker->expr, data));
        if (!marker->lang.empty()) {
            out_lines.push_back(std::format("```{}", marker->lang));
            out_lines.push_back(rendered);
            out_lines.emplace_back("```");
        } else {
            out_lines.push_back(rendered);
        }

        out_lines.push_back(lines[end_idx]);
        i = end_idx;
    }

    std::string result;
    for (std::size_t i = 0; i < out_lines.size(); ++i) {
        if (i > 0) {
            result.push_back('\n');
        }
        result.append(out_lines[i]);
    }
    if (trailing_nl) {
        result.push_back('\n');
    }
    return result;
}

[[nodiscard]] std::string json_arg_to_string(const nlohmann::json& j) {
    if (j.is_string()) {
        return j.get<std::string>();
    }
    return j.dump();
}

[[nodiscard]] std::pair<std::string, std::string> parse_key_value(std::string_view arg, std::string_view flag) {
    const auto eq = arg.find('=');
    if (eq == std::string_view::npos || eq == 0 || eq + 1 >= arg.size()) {
        throw std::runtime_error(std::format("Invalid argument for {} (expected key=value): {}", flag, arg));
    }
    return {std::string(arg.substr(0, eq)), std::string(arg.substr(eq + 1))};
}

void print_usage(std::ostream& os) {
    std::println(
        os,
        "Usage:\n"
        "  docs-render --template <path> --output <path> [options]\n"
        "  docs-render --in-place <path> [--in-place <path> ...] [options]\n"
        "Options:\n"
        "  --template <path>       Input Inja template file (mutually exclusive with --in-place)\n"
        "  --output <path>         Rendered output file (mutually exclusive with --in-place)\n"
        "  --in-place <path>       Update <!-- inja: ... --> blocks in-place (repeatable)\n"
        "  --source-dir <dir>      Base directory for snippets and relative paths (default: .)\n"
        "  --check                 Check if output matches rendered content without writing\n"
        "  --data <key=json_path>  Load JSON file into template context as key (repeatable)\n"
        "  --target <name=exe>     Register executable target for output() (repeatable)\n"
        "  --emulator <cmd>        Cross-compile emulator command prefix\n"
        "  --timeout <seconds>     Executable timeout in seconds (default: 15)\n"
        "  -h, --help              Show this help message"
    );
}

[[nodiscard]] Options parse_args(int argc, char** argv) {
    Options opts;
    auto require_value = [&](int& i, std::string_view flag) -> std::string {
        if (i + 1 >= argc) {
            throw std::runtime_error(std::format("Missing value for option: {}", flag));
        }
        return std::string(argv[++i]);
    };

    for (int i = 1; i < argc; ++i) {
        const std::string_view arg = argv[i];
        if (arg == "-h" || arg == "--help") {
            print_usage(std::cout);
            std::exit(0);
        } else if (arg == "--template") {
            opts.template_path = require_value(i, arg);
        } else if (arg == "--output") {
            opts.output_path = require_value(i, arg);
        } else if (arg == "--in-place") {
            opts.in_place_paths.emplace_back(require_value(i, arg));
        } else if (arg == "--source-dir") {
            opts.source_dir = require_value(i, arg);
        } else if (arg == "--check") {
            opts.check_only = true;
        } else if (arg == "--data") {
            auto [k, v] = parse_key_value(require_value(i, arg), arg);
            opts.data_files.emplace_back(std::move(k), fs::path(std::move(v)));
        } else if (arg == "--target") {
            auto [k, v] = parse_key_value(require_value(i, arg), arg);
            opts.targets[std::move(k)] = std::move(v);
        } else if (arg == "--emulator") {
            opts.emulator = require_value(i, arg);
        } else if (arg == "--timeout") {
            const std::string val = require_value(i, arg);
            opts.timeout_seconds = std::stoi(val);
            if (opts.timeout_seconds <= 0) {
                throw std::runtime_error("--timeout must be a positive integer");
            }
        } else {
            throw std::runtime_error(std::format("Unknown option: {}", arg));
        }
    }

    if (!opts.in_place_paths.empty()) {
        if (!opts.template_path.empty() || !opts.output_path.empty()) {
            throw std::runtime_error("--in-place is mutually exclusive with --template and --output");
        }
    } else {
        if (opts.template_path.empty()) {
            throw std::runtime_error("Either --in-place or --template + --output is required");
        }
        if (opts.output_path.empty()) {
            throw std::runtime_error("--output is required when --template is specified");
        }
    }
    return opts;
}

[[nodiscard]] bool sync_output_file(const fs::path& output_path, std::string_view rendered, bool check_only) {
    std::optional<std::string> existing;
    if (fs::exists(output_path)) {
        existing = normalize_lf(read_file_binary(output_path));
    }

    if (check_only) {
        if (!existing.has_value() || *existing != rendered) {
            std::println(
                std::cerr,
                "docs-render: {} is out of date. Run docs-render to update.",
                output_path.string()
            );
            return false;
        }
        return true;
    }

    if (existing.has_value() && *existing == rendered) {
        return true;
    }

    write_file_binary(output_path, rendered);
    return true;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        const Options opts = parse_args(argc, argv);

        nlohmann::json data = nlohmann::json::object();
        for (const auto& [key, json_path] : opts.data_files) {
            const fs::path resolved = resolve_input_path(json_path, opts.source_dir);
            const std::string raw = read_file_binary(resolved);
            data[key] = nlohmann::json::parse(raw);
        }

        inja::Environment env;

        env.add_callback("snippet", 1, [&](inja::Arguments& args) {
            const auto rel_path = json_arg_to_string(*args.at(0));
            return extract_snippet(opts.source_dir, rel_path, std::nullopt);
        });

        env.add_callback("snippet", 2, [&](inja::Arguments& args) {
            const auto rel_path = json_arg_to_string(*args.at(0));
            const auto region = json_arg_to_string(*args.at(1));
            return extract_snippet(opts.source_dir, rel_path, region);
        });

        env.add_callback("output", [&](inja::Arguments& args) {
            if (args.empty()) {
                throw std::runtime_error("output() requires at least a target name");
            }
            const auto target_name = json_arg_to_string(*args.at(0));
            const auto it = opts.targets.find(target_name);
            if (it == opts.targets.end()) {
                throw std::runtime_error(std::format("Unknown target in output(): {}", target_name));
            }

            std::vector<std::string> cmd = split_command_tokens(opts.emulator);
            cmd.push_back(it->second);
            for (std::size_t i = 1; i < args.size(); ++i) {
                cmd.push_back(json_arg_to_string(*args.at(i)));
            }
            return run_process(cmd, opts.timeout_seconds);
        });

        if (!opts.in_place_paths.empty()) {
            bool all_ok = true;
            for (const auto& rel : opts.in_place_paths) {
                const fs::path file_path = resolve_output_path(rel, opts.source_dir);
                const std::string original = normalize_lf(read_file_binary(file_path));
                const std::string rendered = render_in_place_content(original, file_path, env, data);
                if (!sync_output_file(file_path, rendered, opts.check_only)) {
                    all_ok = false;
                }
            }
            return all_ok ? 0 : 1;
        }

        const fs::path tmpl_path = resolve_input_path(opts.template_path, opts.source_dir);
        const fs::path out_path = resolve_output_path(opts.output_path, opts.source_dir);
        const std::string tmpl_content = normalize_lf(read_file_binary(tmpl_path));
        const std::string rendered = normalize_lf(env.render(tmpl_content, data));

        return sync_output_file(out_path, rendered, opts.check_only) ? 0 : 1;
    } catch (const std::exception& ex) {
        std::println(std::cerr, "docs-render error: {}", ex.what());
        return 1;
    }
}
