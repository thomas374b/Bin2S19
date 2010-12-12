



#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>

#include "tns_util/readln.h"
#include "tns_util/mkopts.h"


#define MAIN_G
#include "tns_util/copyright.h"

void check_hexnum(int i, float f, char *fn);


t_opts opts[] = {
 	{check_hexnum,e_string,'b',"base\0","offset address\t\t\0",false,0,0.0,"0x0\0"},
#define baseaddr opts[0].i

	{empty_func,e_string,'f',"file\0","binary input file\t\0",false,0,0.0,"xyz.bin\0                                                                                                                "},
#define filename opts[1].s

	{empty_func,e_boolean,'s',"s19\0","make s19 output\t\t\0",false,0,0.0,"xyz.bin\0                                                                                                                "},
#define s19out opts[2].b

	{empty_func,e_boolean,'r',"ras\0","random access segments\t\0",false,0,0.0,"xyz.bin\0                                                                                                                "},
#define rasin opts[3].b

	{empty_func,e_boolean,'w',"raw\0","make binary output\t\0",false,0,0.0,"xyz.bin\0                                                                                                                "},
#define rawout opts[4].b

	{empty_func,e_integer,'c',"record\0","s19 record lenght\t\0",false,16,0.0,"xyz.bin\0                                                                                                                "},
#define RecSize opts[5].i

	{empty_func,e_boolean,'x',"hexout\0","make raw hex dump\t\0",false,0,0.0,"xyz.bin\0                                                                                                                "},
#define hexout opts[6].b

/*
 	{do_prefix,e_boolean,'b',"begin\0","match only trigrams at start of string\0",false,0,0.0,"\0"},
#define prefix_mode opts[0].b
 	{do_postfix,e_boolean,'e',"end\0","match only trigrams at end of string\0",false,0,0.0,"\0"},
#define postfix_mode opts[1].b
 	{do_invert,e_boolean,'i',"invert\0","print the matching strings\t\0",false,0,0.0,"\0"},
#define invert_mode opts[2].b
	{empty_func,e_string,'d',"database\0","use word list to extract trigrams\0",false,0,0.0,"database.txt\0                                                                                                          "},
#define database opts[4].s
	{check_penta,e_integer,'p',"penta\0","check for pentagrams or whatever\0",false,3,0.0,"\0                                                                                                                "},
#define tree_depth opts[6].i
	{empty_func,e_boolean,'g',"generate\0","list all trigrams in namespace\t\0",false,3,0.0,"\0                                                                                                                "},
#define generate opts[7].b
*/

	{empty_func,e_unknown,'\0',"\0","\0",0,0,0.0,"\0"}
	};


typedef struct {
	unsigned char ID;
	unsigned char Len;
	unsigned short Addr;
	unsigned char buffer[256];
} t_s19Line;


#define S1_ID	1


unsigned char Hex2Num(char C)
{
	if ((C >= '0') && (C <= '9')) {
		return (C - '0');
	}
	if ((C >= 'A') && (C <= 'F')) {
		return (C - 'A')+10;
	}
	if ((C >= 'a') && (C <= 'f')) {
		return (C - 'a')+10;
	}
	return 0;
}

unsigned char Hex2Byte(char *S)
{
	return (Hex2Num(S[0]) << 4) | Hex2Num(S[1]);	
}

class t_s19Rec {
public:
	t_s19Line *Filled(char *Line, t_s19Line *tmpLine);		
};


t_s19Line *t_s19Rec::Filled(char *Line,t_s19Line *tmpLine)
{
	if ((Line == NULL) || (tmpLine == NULL)) {
		return NULL;
	}
	int Len = strlen(Line);
	if (Len <= 0) {
		return NULL;
	}
	unsigned int CheckSum = 0;
	int i = 0;
	int k = 0;
	if ((Len % 2) == 1) {
//#ifdef DEBUG
	    if (verbose_mode) {
		fprintf(stderr,"Length %d is odd, removing DOS linefeed\n",Len);
	    }
//#endif
	    Len--;
	}
	while (i < Len) {
		char *Test = Line + i;		
#ifdef DEBUG		
		if (verbose_mode) {
		    fprintf(stderr,"evaluating char[%c](byte 0x%04x) at pos %d, checksum 0x%08x\n",*Test,Hex2Byte(Test),i,CheckSum);
		}
#endif
		switch(i) {
			case 0: // ID
				if (*Test != 'S') {
					return NULL;
				}
				switch(Test[1]) {
					case '1':
						tmpLine->ID = 1;
						break;

					default:	
						return NULL;
				}
				break;
				
			case 2: // Len
				tmpLine->Len = Hex2Byte(Test);
				CheckSum += tmpLine->Len;
				CheckSum -= 3;
				break;
				
			case 4: // Addr
				tmpLine->Addr = Hex2Byte(Test);
				CheckSum += tmpLine->Addr;
				tmpLine->Addr <<= 8;					
				tmpLine->Addr |= (Hex2Byte(&Test[2]));
				CheckSum += (tmpLine->Addr & 0xff);
				i+=2;
				break;
					
			default: // Bytes
				tmpLine->buffer[k] = Hex2Byte(Test);
				CheckSum += tmpLine->buffer[k];
				k++; 
				break;
		}
		i+=2;
	}
	if ((CheckSum & 0xff) != 0xff) {
//#ifdef DEBUG
		if (verbose_mode) {
		    fprintf(stderr,"checksum 0x%04x did not match\n",CheckSum);
//		    exit(1);
		}
//#endif		
		return NULL;
	}
	tmpLine->Len -= 3;
	return tmpLine;
}

void check_hexnum(int i, float f, char *fn)
{
	char st[256];
	int d;
	
	if (sscanf(fn,"0x%s",st) == 1) {
		char *s = st;
		baseaddr = 0;
		while (strlen(s) > 1) {
		    baseaddr |= Hex2Num(*s);
		    baseaddr <<= 4;
		    s++;
		} 
		if (verbose_mode) {
		    fprintf(stderr,"got baseaddr: 0x%04x\n",baseaddr);
		}
		return;
	}
	baseaddr = 0;
}


void makeS19(void)
{
	unsigned char buf[65536 + 4096];

	if (verbose_mode) {
		fprintf(stderr,"open binary file \"%s\"\n",filename);
	}	
	int ifd = open(filename,O_RDONLY);
	if (ifd < 0) {
		fprintf(stderr,"open(\"%s\") failed: %s\n",filename,strerror(errno));
		_exit(1);
	}
	int Size = read(ifd,buf,65536);
	close(ifd);
		
	int k = 0;
	int Length = 0;
	int q = 0;
	int Len = 0;
	
	while (k < Size) {
		if (rasin) {
			if (q == Length) {
				q = 0;
			}
			if (q == 0) {
				unsigned short *O,*L;
				O = (unsigned short *)&buf[k];
				L = (unsigned short *)&buf[k+2];
				baseaddr = *O;
				Length = *L;
				k += 4;
				if (verbose_mode) {
					fprintf(stderr,"segment: 0x%04x, len: %d\n",*O,*L);
				}
			}				
			Len = Length -q;
		} else {
			Len = Size -k;
		}


		if (Len > RecSize)
			Len = RecSize;

		int ChkSum = 0;
		ChkSum += Len;
		
		int Addr = baseaddr;
		if (rasin) {
			Addr += q;
		} else {
			Addr += k;
		}			
		ChkSum += (Addr >> 8);
		ChkSum += Addr & 0xff;				
		
		if (!(hexout)) {
			printf("S1%02X%04X",Len+3,Addr);
		} else {
			printf("%04X:",Addr);
		}	
			
		for (int i=0; i<Len; i++) {
			printf("%02X",buf[i+k]);
			ChkSum += buf[i+k];
		}		
		
		if (!(hexout)) {
			printf("%02X\r\n",(unsigned char)(0xff - (ChkSum & 0xff)));
		} else {
			printf("\n");
		}			

		k += Len;
		q += Len;
	}
	if (!(hexout)) {
		printf("S903FFFFFE\r\n");
	}		
}

void makeRaw(void) 
{
	t_buffer FBuf;
	char fn[256];
	sprintf(fn,"%s.s19",filename);

	if (verbose_mode) {
		fprintf(stderr,"open s19 format file \"%s\"\n",filename);
	}	
	if (FBuf.Init(fn,32768) == false) {
		fprintf(stderr,"open %s.s19 failed\n",filename);
		_exit(1);
	}
	char Binary[0x10000];
	memset(Binary,0xff,0x10000);
	int lowest,highest;
	lowest = 0x10000;
	highest = 0;
	
	char *L = FBuf.ReadLn();
	while (L != NULL) {
		t_s19Rec S19Rec;
		t_s19Line S1Line,*got;
				
/*		int l = strlen(L);
		if (L > 0) {
		    if (L[l-1] == 13) {
			if (verbose_mode) {
			    fprintf(stderr,"DOS linefeed removed\n");
			}     
			L[l-1] = 0;	
		    }
		}
*/
#ifdef DEBUG
		if (verbose_mode) {
		    fprintf(stderr,"parsing line \"%s\"\n",L);
		}
#endif		
		got = S19Rec.Filled(L,&S1Line);
		if (got != NULL) {
			memcpy(&Binary[got->Addr],got->buffer,got->Len);	
			if (highest < got->Addr+got->Len) {
				highest = got->Addr+got->Len;
			}
			if (lowest > got->Addr) {
				lowest = got->Addr;
			}
			
		} else {
#ifdef DEBUG
		    if (verbose_mode) {
				fprintf(stderr,"no valid S19line\n");
		    }
#endif
		}
		L = FBuf.ReadLn();
	}
	FBuf.Done();
	
	int Size = (highest - lowest);
	if (Size > 0) {
		char fn[256];
		sprintf(fn,"%s-0x%04x.bin",filename,lowest);
		int fd = open(fn,O_RDWR|O_CREAT|O_TRUNC,0644);
		if (fd > 0) {
			if (write(fd,&Binary[lowest],Size) != Size) {
				fprintf(stderr,"could not write \"%s\": %s\n",fn,strerror(errno));
			}
			close(fd);
		}
	} else {
	    if (verbose_mode) {
			fprintf(stderr,"size was 0, no file written\n");
	    }
	}
}

int main(int argc, char *argv[])
{
	scan_args(argc,argv,opts);

	if (s19out || rasin) {
		makeS19();
	} else {
		if (rawout) {
			if (verbose_mode) {
			    fprintf(stderr,"make raw output from s19\n");
			}        
			makeRaw();
		} else {
			fprintf(stderr,"you have to choose option -s or -r\n");
		}
	}
}
