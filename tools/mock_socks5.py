import socket
import struct
import time
import sys

def main():
    HOST = '127.0.0.1'
    PORT = 40000

    print(f"Starting Mock SOCKS5 Server on {HOST}:{PORT}")
    
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(1)
        
        # Flush stdout to ensure agent sees it
        sys.stdout.flush()
        
        conn, addr = s.accept()
        with conn:
            print(f"Connected by {addr}")
            
            # 1. Auth Negotiation
            data = conn.recv(1024)
            print(f"Auth Request: {data.hex()}")
            if not data or data[0] != 0x05:
                print("Invalid SOCKS5 version")
                return

            # Respond No Auth Required
            conn.sendall(b'\x05\x00')
            
            # 2. Request
            data = conn.recv(1024)
            print(f"Connect Request: {data.hex()}")
            if len(data) < 4:
                return

            ver, cmd, rsv, atyp = data[0], data[1], data[2], data[3]
            
            if cmd == 0x01: # CONNECT
                target_addr = ""
                target_port = 0
                
                if atyp == 0x01: # IPv4
                    ip_bytes = data[4:8]
                    target_addr = socket.inet_ntoa(ip_bytes)
                    target_port = struct.unpack('!H', data[8:10])[0]
                elif atyp == 0x03: # Domain
                    addr_len = data[4]
                    target_addr = data[5:5+addr_len].decode()
                    target_port = struct.unpack('!H', data[5+addr_len:5+addr_len+2])[0]
                
                print(f"SUCCESS: Intercepted connection to {target_addr}:{target_port}")
                
                # Reply success
                # VER REP RSV ATYP BND.ADDR BND.PORT
                reply = b'\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00'
                conn.sendall(reply)
                
            else:
                print(f"Unsupported CMD: {cmd}")

if __name__ == '__main__':
    main()
