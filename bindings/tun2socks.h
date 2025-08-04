#ifndef TUN2SOCKS_H
#define TUN2SOCKS_H

#ifdef __cplusplus
extern "C" {
#endif

void tun2socks_start(const char *ifname, const char *proxy, const char *dns);
void tun2socks_stop(void);

#ifdef __cplusplus
}
#endif

#endif // TUN2SOCKS_H
