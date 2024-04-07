#include "rate_tool.h"
#include "linklist.h"

rateList *ip_stats_head = NULL;
pthread_mutex_t mutex;
int num_ips = 0;

void calculated_rate(const unsigned long rate,char *_rate_unit)
{
    unsigned long _rate = rate;
    char rate_unit[32] = {0};

    if(_rate > 1024)
    {
        double rate_d = (double)_rate / 1024;
        if( rate_d > 1024)
        {
            rate_d = rate_d / 1024;
            sprintf(rate_unit,"%0.1f%s",rate_d,"MB/s");
        }
        else
        {
            sprintf(rate_unit,"%0.1f%s",rate_d,"KB/s");
        }
    }
    else
    {
        if(_rate > 102)
        {
            //printf("%ld\n",_rate);
            double rate_d = (double)_rate / 1024;
            sprintf(rate_unit,"%0.1f%s",rate_d,"KB/s");
        }
        else
        {
            sprintf(rate_unit,"0.0%s","KB/s");
        }
    }
    strcpy(_rate_unit,rate_unit);
 
    return ;
}

int write_tmp_file()
{
    rateList *p;
    FILE *fp = NULL;
    char send_rate[32] = {0};
    char recv_rate[32] = {0};

    fp = fopen(IP_RATE_INFO_FILE,"w");
    if(fp == NULL)
    {
        printf("open %s fail!\n",IP_RATE_INFO_FILE);
        return -1;
    }

    fprintf(fp,"%-16s %-10s\t%-10s\n","ip","send_bytes","recv_bytes");
    p = ip_stats_head->next;
    while(p != NULL)
    {
        calculated_rate(p->sent_bytes,send_rate);
        calculated_rate(p->recv_bytes,recv_rate);
        fprintf(fp,"%-16s %-10s\t%-10s\n",p->ip,send_rate,recv_rate);
        p = p->next;
    }
    
    fflush(fp);
    fclose(fp);

    return 0;
}

int check_file_status(const char *fileName)
{
    struct stat st;
    static time_t lastModified_time = 0;

    if(stat(fileName,&st) == -1)
    {
        perror("stat");
        return NOT_FILE_MODIFIED;
    }

    if(lastModified_time != st.st_mtime)
    {   
        if(lastModified_time == 0)
        {
            lastModified_time = st.st_mtime;
            return NOT_FILE_MODIFIED;
        }
        lastModified_time = st.st_mtime;
        return FILE_MODIFIED;
    }
    
    return NOT_FILE_MODIFIED;
}

void* pthread_write_file()
{
    rateList *p;
    
    for(;;)
    {
        sleep(1);
        write_tmp_file();
        p = ip_stats_head->next;
        while(p != NULL)
        {
            pthread_mutex_lock(&mutex);
            p->sent_bytes = 0;
            p->recv_bytes = 0;
            pthread_mutex_unlock(&mutex);
            p = p->next;
        }
        if(check_file_status(DHCP_PATH) == FILE_MODIFIED)
        {
            update_ratelist(ip_stats_head);
            p = ip_stats_head;
            while(p != NULL)
            {
                //printf("%s\n",p->ip);
                p = p->next;
            }
        }
    }

    pthread_exit(NULL);
}

void packet_handler(u_char *user, const struct pcap_pkthdr *pkthdr, const u_char *packet) {
    struct ether_header *eth_header = (struct ether_header *) packet;
    struct ip *ip_header = (struct ip *) (packet + sizeof(struct ether_header));

    // Check if the packet is IP
    if (ntohs(eth_header->ether_type) == ETHERTYPE_IP) {
        char src_ip[MAX_IP_LEN];
        char dst_ip[MAX_IP_LEN];
        strcpy(src_ip, inet_ntoa(ip_header->ip_src));
        strcpy(dst_ip, inet_ntoa(ip_header->ip_dst));

        //printf("src_ip %s dst_ip %s\n",src_ip,dst_ip);
        rateList *p = ip_stats_head->next;
        while(p != NULL)
        {
            if (strcmp(src_ip, p->ip) == 0) {
                pthread_mutex_lock(&mutex);
                p->sent_bytes += ntohs(ip_header->ip_len);
                pthread_mutex_unlock(&mutex);
                //printf("ip %s sent %ld,%d\n",p->ip,p->sent_bytes,ntohs(ip_header->ip_len));
            }

            if (strcmp(dst_ip, p->ip) == 0) {
                pthread_mutex_lock(&mutex);
                p->recv_bytes += ntohs(ip_header->ip_len);
                pthread_mutex_unlock(&mutex);
                //printf("ip %s recv %ld,%d\n",p->ip,p->recv_bytes,ntohs(ip_header->ip_len));
            }
            p = p->next;
        }

    }
}

int main(int argc, char *argv[]) {
    int ret = 0;
    pthread_t thread[2] = {0};

    pthread_mutex_init(&mutex,NULL);

    ip_stats_head = createList(ip_stats_head);

    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t *handle;

    // Open the network device for capturing packets
    handle = pcap_open_live("br-lan", BUFSIZ, 1, 1000, errbuf);
    if (handle == NULL) {
        fprintf(stderr, "Couldn't open device: %s\n", errbuf);
        return 1;
    }

    // Set the filter to capture only IP packets
    struct bpf_program fp;
    char filter_exp[] = "ip";
    if (pcap_compile(handle, &fp, filter_exp, 0, PCAP_NETMASK_UNKNOWN) == -1) {
        fprintf(stderr, "Couldn't parse filter %s: %s\n", filter_exp, pcap_geterr(handle));
        return 1;
    }
    if (pcap_setfilter(handle, &fp) == -1) {
        fprintf(stderr, "Couldn't install filter %s: %s\n", filter_exp, pcap_geterr(handle));
        return 1;
    }

    if((ret = pthread_create(&thread[0],NULL,pthread_write_file,NULL)) != 0)
    {
        printf("pthread_create filed !\n");
        return 1;
    }
    else
    {
        printf("pthread_create success!\n");
    }

    // Start capturing packets
    pcap_loop(handle, -1, packet_handler, NULL);

    // Close the capture handle
    pcap_close(handle);

    pthread_mutex_destroy(&mutex);

    return 0;
}
