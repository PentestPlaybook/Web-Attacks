# DVWA Penetration Testing Lab Documentation

## Overview
This repository contains comprehensive documentation for setting up and testing various web application vulnerabilities using DVWA (Damn Vulnerable Web Application) in a controlled lab environment.

## ⚠️ Security Notice
**This documentation is for educational and authorized security testing purposes only.**

- All credentials, IP addresses, and configurations are for isolated lab environments
- Do NOT use these techniques against systems you don't own or have explicit permission to test
- Credentials shown are examples for local testing only and should be changed in any real deployment
- SSH keys and session tokens have been redacted where appropriate

## Contents

### Environment Setup
- WSL2 + Kali Linux installation
- Apache, MariaDB, and PHP configuration
- DVWA installation and database setup
- SSH key-based authentication setup
- Network configuration (port forwarding, firewall rules)

### Vulnerability Testing Coverage
1. **Command Injection** - OS command execution via web input
2. **File Upload Vulnerabilities** - Malicious file upload and web shell deployment
3. **SQL Injection (SQLi)** - Database enumeration and exploitation
4. **Cross-Site Scripting (XSS)** - Reflected, Stored, and DOM-based XSS
5. **Cross-Site Request Forgery (CSRF)** - Various CSRF attack vectors
6. **Local File Inclusion (LFI)** - Log poisoning, SSH key extraction
7. **Remote File Inclusion (RFI)** - Remote code execution
8. **Brute Force Attacks** - Password cracking with Hydra and Burp Suite

### Tools Used
- Kali Linux
- Burp Suite
- netcat
- curl
- Hydra
- Custom PHP shells and payloads

## Lab Environment
- **Platform**: Windows with WSL2 (Kali Linux)
- **Web Server**: Apache 2.4.63
- **Database**: MariaDB
- **Target Application**: DVWA (Low security level)
- **Network**: Isolated local network for testing

## Usage Notes
- All examples use `127.0.0.1` or `dvwa.local` for local testing
- Firefox with proxy configuration for Burp Suite integration
- Commands are provided for both browser-based and CLI-based exploitation

## Prerequisites
- Basic understanding of web application security
- Familiarity with Linux command line
- Understanding of HTTP protocols
- Knowledge of SQL, PHP, and JavaScript basics

## Disclaimer
This material is provided for educational purposes. The author assumes no liability for misuse of this information. Always obtain proper authorization before conducting security testing.

## License
Educational use only. Not for production environments.
