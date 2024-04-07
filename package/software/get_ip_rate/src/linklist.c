#include "linklist.h"

rateList *initHead(rateList *L)
{
    L = (rateList*)malloc(sizeof(rateList));
    L->next = NULL;
}

rateList *createList(rateList *L)
{
    int i;
    FILE *fp = NULL;
    char line[256] = {0};
    char *token = NULL;
    rateList *head = NULL,*node,*p;
    head = initHead(head);
    p = head;

    fp = fopen(DHCP_PATH,"r");
    if(fp == NULL)
    {
        printf("open file faild !\n");
        return NULL;
    }

    while(fgets(line , sizeof(line) , fp))
    {
        i = 0;
        for(token = strtok(line," \n"); token != NULL; token = strtok(NULL," \n"))
        {
            //printf("%s\n",token);
            i++;
            if(i == 3)
            {
                //printf("dhcp %s\n",token);
                node = (rateList *)malloc(sizeof(rateList));
                strcpy(node->ip,token);
                node->sent_bytes = 0;
                node->recv_bytes = 0;
                node->stat = ENABLE;
                node->next = NULL;
                p->next = node;
                p = p->next;
            }
        }
    }

    fclose(fp);

    return head;
}

void update_ratelist(rateList *L)
{
    int i;
    FILE *fp = NULL;
    char line[256] = {0};
    char *token = NULL;
    int insertFlag;
    rateList *p = L->next;
    
    while(p != NULL)
    {
        p->stat = DISABLE;
        p = p->next;
    }

    fp = fopen(DHCP_PATH,"r");
    if(fp == NULL)
    {
        printf("open file faild!\n");
        return;
    }

    while(fgets(line , sizeof(line) , fp))
    {
        i = 0;
        for(token = strtok(line," \n"); token != NULL; token = strtok(NULL," \n"))
        {
            i++;
            if(i == 3)
            {
                insertFlag = ENABLE;
                p = L->next;
                while(p != NULL)
                {
                    if(strcmp(p->ip,token) == 0)
                    {
                        p->stat = ENABLE;
                        insertFlag = DISABLE;
                        break;
                    }
                    p = p->next;
                }
                if(insertFlag == ENABLE)
                {
                    insertTail(L,token);
                }
            }
        }
    }

    deleteDisNode(L);

    return;
}

void insertTail(rateList *L,char *nodeIp)
{
    rateList *p = L,*node;

    while(p->next != NULL)
    {
        p = p->next;
    }

    node = (rateList*)malloc(sizeof(rateList));
    strcpy(node->ip,nodeIp);
    node->recv_bytes = 0;
    node->sent_bytes = 0;
    node->stat = ENABLE;
    node->next = NULL;
    p->next = node;
    //printf("linklist insert ip:%s\n",nodeIp);

    return;
}

void deleteDisNode(rateList *L)
{
    rateList *p = L;

    while((p->next != NULL))
    {
        if(p->next->stat == DISABLE)
        {
            //printf("delete node ip:%s\n",p->next->ip);
            if(p->next->next == NULL)
            {
                p->next = NULL;
            }
            else
            {
                p->next = p->next->next;
            }
            free(p->next);
        }
        else
        {
            p = p->next;
        }
    }

    return;
}