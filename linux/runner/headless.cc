#include "headless.h"

#include <unistd.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits.h>
#include <string>
#include <vector>

int launch_headless(int argc, char** argv) {
  const char* display = std::getenv("DISPLAY");
  const char* wayland = std::getenv("WAYLAND_DISPLAY");
  bool headless = (!display || !*display) && (!wayland || !*wayland);
  for (int i = 1; i < argc; ++i) {
    const std::string arg(argv[i]);
    if (arg == "--help") {
      std::puts("FunClash [--headless] [--data-dir PATH] [--panel-port PORT]\n"
                "  --panel / --no-panel           Save panel enabled state\n"
                "  --allow-lan / --no-allow-lan   Save LAN access state\n"
                "  --panel-url                   Print link and exit\n"
                "  --show-disclaimer             Print terms and exit\n"
                "  --accept-disclaimer           Accept terms for headless startup\n"
                "Without a display, a virtual X11 session starts automatically.");
      return 0;
    }
    if (arg == "--headless" || arg.find("--panel") == 0 ||
        arg == "--no-panel" || arg == "--allow-lan" ||
        arg == "--no-allow-lan" || arg.find("--data-dir") == 0 ||
        arg == "--show-disclaimer" || arg == "--accept-disclaimer") {
      headless = true;
    }
  }
  const char* active = std::getenv("FUNCLASH_HEADLESS");
  if (!headless || (active && std::strcmp(active, "1") == 0)) return -1;
  char buffer[PATH_MAX + 1];
  const ssize_t length = readlink("/proc/self/exe", buffer, PATH_MAX);
  if (length < 0) return 1;
  buffer[length] = '\0';
  const std::string binary(buffer);
  std::string launcher = binary.substr(0, binary.find_last_of('/')) +
                         "/funclash-headless";
  std::vector<char*> command = {&launcher[0], buffer};
  for (int i = 1; i < argc; ++i) command.push_back(argv[i]);
  command.push_back(nullptr);
  execv(command[0], command.data());
  std::fprintf(stderr, "Cannot launch %s: %s\n", launcher.c_str(), std::strerror(errno));
  return 1;
}
