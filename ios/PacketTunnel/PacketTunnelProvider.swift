import NetworkExtension

@_silgen_name("StartXray")
func StartXray(_ config: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("StopXray")
func StopXray() -> UnsafeMutablePointer<CChar>?

@_silgen_name("FreeCString")
func FreeCString(_ str: UnsafeMutablePointer<CChar>)

@_silgen_name("tun2socks_start")
func tun2socks_start(_ ifname: UnsafePointer<CChar>, _ proxy: UnsafePointer<CChar>, _ dns: UnsafePointer<CChar>)

@_silgen_name("tun2socks_stop")
func tun2socks_stop()

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var activeSettings: NEPacketTunnelNetworkSettings?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        startLocalProxy()

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])

        let proxy = NEProxySettings()
        proxy.socksServer = NEProxyServer(address: "127.0.0.1", port: 1080)
        proxy.excludeSimpleHostnames = false
        proxy.matchDomains = [""]
        settings.proxySettings = proxy

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let err = error {
                completionHandler(err)
                return
            }
            self?.activeSettings = settings

            DispatchQueue.global().async {
                "utun233".withCString { ifPtr in
                    "127.0.0.1:1080".withCString { proxyPtr in
                        "8.8.8.8".withCString { dnsPtr in
                            tun2socks_start(ifPtr, proxyPtr, dnsPtr)
                        }
                    }
                }
            }

            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        tun2socks_stop()
        stopLocalProxy()
        completionHandler()
    }

    private func startLocalProxy() {
        guard let configURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.xstream")?.appendingPathComponent("xray_config.json"),
              let data = try? Data(contentsOf: configURL),
              let configStr = String(data: data, encoding: .utf8) else { return }

        configStr.withCString { ptr in
            if let res = StartXray(ptr) {
                FreeCString(res)
            }
        }
    }

    private func stopLocalProxy() {
        if let res = StopXray() {
            FreeCString(res)
        }
    }
}
