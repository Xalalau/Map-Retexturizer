/*
 * por Xalalau Xubilozo
 * https://github.com/xalalau/GMBR-DS
 * Licença: GPL v2
 * */

#ifndef HEADER_FILE
#define HEADER_FILE
  #include <stdio.h>
  #include <string.h>
  #include <stdlib.h>
  #include <sys/stat.h>
  #include <errno.h>
  #if __linux__
    #include <unistd.h>
    #include <pwd.h>
    #define ShellExecute(a, b, c, d, e, f) printf("Nada") /* Definicao desbugante de Linux */
  #elif _WIN32
    #include <direct.h>
    #include <windows.h>
  #endif
  #include "../lib/Xalateca/C/Geral/src/geral.h"
  #include "../lib/Xalateca/C/Inizator/src/inizator.h"
#endif