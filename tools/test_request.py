import socket
import sys
import time

def test_connection():
    domain = "sys-test.com"
    port = 80
    
    print(f"Resolving {domain}...")
    try:
        # This should trigger getaddrinfo hook -> FakeIP
        addr_info = socket.getaddrinfo(domain, port, socket.AF_INET, socket.SOCK_STREAM)
        ip = addr_info[0][4][0]
        print(f"Resolved IP: {ip}")
        
        # Check if it looks like a FakeIP (198.18.x.x)
        if ip.startswith("198.18."):
            print("SUCCESS: FakeIP detected!")
        else:
            print(f"WARNING: Resolved to real IP {ip}, Hook might make failed?")

        print(f"Connecting to {ip}:{port}...")
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        # This should trigger connect hook
        s.connect((ip, port))
        print("Connected!")
        s.close()
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_connection()
