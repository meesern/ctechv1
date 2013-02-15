#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <termios.h>

#define USBPACKLEN 36

#define POLLCOMMAND 2
#define ACCUMS 4


typedef struct {
  unsigned char responseType;
  unsigned char transId;
  unsigned char fineGrain;
  unsigned char adapting;

  unsigned char serialnum[4];

  unsigned int instantRMScurrent;

  unsigned int samples;
  unsigned int accumLo;
  unsigned int accumHi;
  unsigned short timer1;
  unsigned short timer2;
  unsigned short ticks;
  unsigned char suspDis;

   // unsigned int accum[ACCUMS];
  //unsigned short samplesPerSec;
  //unsigned short samples[ACCUMS];

} T_pollResponse;

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
    tios.c_cc[VMIN] = USBPACKLEN;
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

  tcflush(sock, TCIFLUSH);   // Clear any rubbish out

  got = write(sock, buff, USBPACKLEN);  
  if (got != USBPACKLEN)	printf("wrote %d\n", got);
  got = read (sock, buff, USBPACKLEN);
  if (got == -1)
    {
      fprintf(stderr, "ERROR Can't read from device (%s)\n",
	      strerror(errno));
      return -1;
    }
  if (got !=USBPACKLEN)
    {
      printf ("got %d\n", got);
      if (got > 0) for (i=0;i<got;i++) printf("%d: 0x%x \'%c\'\n",
					      i, buff[i], buff[i]);
      printf ("\n");
      return -1;
    }
  return 0;
}

int main(int argc, char **argv)
{
  int sock,i, j;
  unsigned char buff[40];
  unsigned long sampTot;
  char * devname;

  T_pollResponse *resPtr;
	
  if (argc > 1)
    devname = argv[1];
  else
    devname = "/dev/ttyACM0";
  
  printf("device: %s \n",devname);
  sock = openrawtty(devname);
  if (sock == -1) return -1;

  buff[0] = POLLCOMMAND;
  buff[1] = 0x3c;
  command(sock, buff);

  // Results back in buff ....

  resPtr = (T_pollResponse *) buff;

  printf("responseType: 0x%x\n", resPtr->responseType);
  printf("transId: 0x%x\n", resPtr->transId);
  printf("fineGrain: 0x%x\n", resPtr->fineGrain);
  printf("adapting: 0x%x\n", resPtr->adapting);
  printf("serialnum: '%c%c%c%c'\n", resPtr->serialnum[0],resPtr->serialnum[1],resPtr->serialnum[2],resPtr->serialnum[3]);
  printf("instantRMScurrent: %d\n", resPtr->instantRMScurrent);
  printf("samples: %d\n", resPtr->samples);
  printf("accumLo: %d\n", resPtr->accumLo);
  printf("accumHi: %d\n", resPtr->accumHi);
  printf("timer1: %d\n", resPtr->timer1);
  printf("timer2: %d\n", resPtr->timer2);
  printf("ticks: %d\n", resPtr->ticks);
  printf("suspDis: %d\n", resPtr->suspDis);

  close (sock);   
}

