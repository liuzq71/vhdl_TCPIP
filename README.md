# TCP/IP Endpoint
TCP/IP Endpoint (inc DHCP)

The stack implements a TCP/IP endpoint (including DHCP). It interfaces with Microchip's ENC28J60 chip which implements the MAC and PHY layers.

It can be used as a client which performs a TCP connection to a server (in which case it can dynamically obtain an IP address via a DHCP request) or as a 'server' for which other clients may connect by initiating a TCP connection.

Future plans are to implement the MAC layer in VHDL and then interface the core directly with a 100/1000 Mb PHY chip.

Performance wise it can achieve about 10Mb/s, which is limited by the ENC28J60, if converted to directly use a PHY there is no reason it couldn't achieve 100Mb/s or better.

Main drawback is that it only supports one TCP connection at a time, something else that I am going to eventually change when I get the time

ENC28J60 modules are extremely inexpensive ($2 USD) and available on Ebay - http://www.ebay.com/itm/New-ENC28J60-Ethernet-LAN-Network-Module-For-Arduino-SPI-AVR-PIC-LPC-STM32-/310670027142?hash=item4855606986:g:XyoAAOxyhodRzTyz
