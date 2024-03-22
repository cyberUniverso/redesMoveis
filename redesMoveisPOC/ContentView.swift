import SwiftUI
import Network
import Foundation
        
struct ContentView: View {
    
    @State var ipName = getIpAddress() ?? ""
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("IP \(ipName)")
            
            Button("Testar Conexão") {
                //requestNetwork()
                ipName = getIpAddress() ?? ""
            }.buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

func requestNetwork() {
    print("Iniciando Implementação")
    let retorno = sendRequest(host: "https://google.com") { state, respose in
        print("aqui")
    }
    print(retorno)
}


enum CellularHttpResult: String {
    case ERROR
    case CELLULAR_UNAVAILABLE
    case SUCCESS
}

private func sendRequest(host: String, completion: @escaping (CellularHttpResult, String) -> Void){
    let hostTcp: NWEndpoint.Host = .init(host)
    //Create state handler, if error return Error back to the client
    let cellularConnection = createCellularConnection(host: hostTcp)
    cellularConnection.stateUpdateHandler = { state in
        print("Trocou")
        switch state {
            case .failed(let error):
                completion(CellularHttpResult.ERROR, "")
            case .cancelled:
                completion(CellularHttpResult.ERROR, "")
            default:
                break
        }
    }
    
    // Create raw http request
    var rawHTTPRequest: String = ""
            
//    do {
//        rawHTTPRequest = try HttpRequest().create(host: host, msisdn: msisdn, apiToken:
//        apiToken)
//    } catch {
//        completion(CellularHttpResult.ERROR, "")
//    }
    
    //Check if cellular is available
    let nwPathMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
    nwPathMonitor.pathUpdateHandler = { path in
    DispatchQueue.main.async {
        switch path.status {
            case .unsatisfied:
                completion(CellularHttpResult.CELLULAR_UNAVAILABLE, "")
            default:
                print("Cellular available")
            }
        }
    }
    nwPathMonitor.start(queue: .main)
    // Send request and handle response
    cellularConnection.send(content: rawHTTPRequest.data( using: .ascii ), completion: .contentProcessed( { error in
        
        print(error)
        cellularConnection.receive(minimumIncompleteLength: 2, maximumLength: 4_096) { data,
            context, isComplete, error in
            
            if let data = data, !data.isEmpty {
                let jsonBody = ""// HttpResponse().parseBody(data: data)
                completion(CellularHttpResult.SUCCESS, jsonBody)
            }
        }
    }))
}


// Setup arguments to force cellular
private func createCellularConnection(host: NWEndpoint.Host) -> NWConnection {
    var connection: NWConnection
    let tcpOptions = NWProtocolTCP.Options()
    
    tcpOptions.connectionTimeout = 10
    let params = NWParameters(tls: .init(), tcp: tcpOptions)
    params.requiredInterfaceType = .cellular
    params.prohibitExpensivePaths = false
    params.prohibitedInterfaceTypes = [.wifi]
    connection = NWConnection(host: host, port: 443, using: params)
    connection.start(queue: .main)
    return connection
}

#Preview {
    ContentView()
}

func getIpAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                } else if (name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3") {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(1), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
