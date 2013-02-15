

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <termios.h>

#define RESPACKLEN 36



static int openrawtty(char device[64])
{

    struct termios tios;

    int sock;



    sock = open(device, O_RDWR | O_NOCTTY);
    if (sock == -1) {
        fprintf(stderr, "ERROR Can't open the device %s (%s)\n",
                device, strerror(errno));
        return -1;
    }


    tcgetattr(sock, &tios);
    cfmakeraw(&tios);
  

    tios.c_cc[VMIN] = RESPACKLEN;
    tios.c_cc[VTIME] = 4;

    tcflush(sock, TCIFLUSH);
    if (tcsetattr(sock, TCSANOW, &tios) < 0) {
        return -1;
    }


    return sock;
}


int command (int sock, unsigned char *buff)
{
  int got, i;

  tcflush(sock, TCIFLUSH);


  got = write(sock, buff, RESPACKLEN);  
  if (got != RESPACKLEN)printf("wrote %d\n", got);
  got = read (sock, buff, RESPACKLEN);
  if (got == -1)
    {
      fprintf(stderr, "ERROR Can't read from device (%s)\n",
	      strerror(errno));
      return -1;
    }
  if (got !=RESPACKLEN)
    {
      printf ("got %d\n", got);
      if (got > 0) for (i=0;i<got;i++) printf("%d: 0x%x \'%c\'\n",
					      i, buff[i], buff[i]);
      printf ("\n");
      return -1;
    }
  return 0;
}

int main(int argc, char *argv[])
{
	int sock;
	int i;
	int sernum;
	unsigned char *dev;
	unsigned char buff[40];
	
	if (argc != 3){
	  printf("usage: %s dev sernum\n", argv[0]);
	  printf("   eg: %s /dev/ttyACM0 5xx\n", argv[0]);
	  return;
	}

	if (!atoi(argv[2])){
	  printf("invalid serial number\n");
	  return;
	}
	dev = argv[1];
	sernum = atoi(argv[2]);
	sock = openrawtty(dev);

	if (sock == -1) 
	{
	  printf("Cant' open device: %s", dev);
	  return -1;
	}

	buff[0] = 0x42;

	buff[1] = 13;
	buff[2] = (sernum / 1000) + '0';
	buff[3] = (sernum / 100) % 10 + '0';
	buff[4] = (sernum / 10) % 10 + '0';
	buff[5] = sernum % 10 + '0';

	command(sock, buff);
	//	for (i=0;i<12;i++) printf ("0x%x\n", buff[i]);
	close (sock);   
}


