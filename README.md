# TCP/IP Endpoint
TCP/IP Endpoint (inc DHCP)

## Requires

ENC28J60. Available [online](http://www.ebay.com/itm/New-ENC28J60-Ethernet-LAN-Network-Module-For-Arduino-SPI-AVR-PIC-LPC-STM32-/310670027142?hash=item4855606986:g:XyoAAOxyhodRzTyz)

## Short Description

The project implements a TCP/IP endpoint (including DHCP). It interfaces with Microchip's ENC28J60 chip which implements the MAC and PHY layers.

It can be used as a client which performs a TCP connection to a server (in which case it can dynamically obtain an IP address via a DHCP request) or as a 'server' for which other clients may connect by initiating a TCP connection.

## Performance

It can achieve about 10Mb/s, which is limited by the ENC28J60, if converted to directly use a PHY there is no reason it couldn't achieve 100Mb/s or better.

## Drawbacks

Only supports one TCP connection at a time

## Future Developments

Implement the MAC layer in VHDL and then interface the core directly with a 100/1000 Mb PHY chip. Also modify to handle multiple connections at one time.

## Licence

Licensed under the GPLv3: http://www.gnu.org/licenses/gpl-3.0.html
