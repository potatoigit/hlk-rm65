obj-app = get_ip_rate
obj-dep = $(OBJS) 

CFLAGS  =  -fPIC 
LDLIBS +=  -lpcap -lpthread
LDFLAGS += -Wall

MYSRC    = ${shell pwd}

BIN_SRC=$(shell echo $(MYSRC)/*.c)

OBJS=$(patsubst %.c,%.o, $(BIN_SRC))

#build: $(obj-app)

$(obj-app):$(obj-dep)
	@echo "BUILD         $(obj-app)  "
	$(CC) $(LDFLAGS) $(LDLIBS) -o $@ $^
	#@$(CC) $(CFLAGS) $(LDFLAGS) $(LDLIBS) $(MYLDLIBS) -o $(obj-app) $(obj-dep) $(LDLIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $^

#.PHONY: all install clean

#all:

install:
	#cp ./files/* $(PKG_BUILD_DIR)/files/
	@echo "INSTALL       $(obj-app)"

clean:
	rm -f $(PKG_BUILD_DIR)/