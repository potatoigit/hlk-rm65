#ifndef _RATE_TOOL_H
#define _RATE_TOOL_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <netinet/ip_icmp.h>
#include <netinet/if_ether.h>
#include <pcap.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <sys/stat.h>

#define MAX_IP_LEN 16
#define IP_RATE_INFO_FILE "/tmp/ip_rate_info"

enum FILE_STAT_E
{
    FILE_MODIFIED = 0,
    NOT_FILE_MODIFIED
};

#endif