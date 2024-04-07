#ifndef _LINKLIST_
#define _LINKLIST_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DHCP_PATH "/tmp/dhcp.leases"

enum DHCP_IP_STAT_E
{
    DISABLE = 0,
    ENABLE 
};

typedef struct ip_stat {
    char ip[16];
    unsigned long sent_bytes;
    unsigned long recv_bytes;
    int stat;
    struct ip_stat *next;
}rateList;

extern rateList *createList(rateList *L);
extern void insertTail(rateList *L,char *nodeIp);
extern void deleteDisNode(rateList *L);
extern void update_ratelist(rateList *L);

#endif