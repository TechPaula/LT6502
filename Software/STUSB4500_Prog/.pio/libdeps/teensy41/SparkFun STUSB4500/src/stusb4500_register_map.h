#define DEFAULT                0xFF

#define FTP_CUST_PASSWORD_REG  0x95
#define FTP_CUST_PASSWORD      0x47

#define FTP_CTRL_0             0x96
#define FTP_CUST_PWR           0x80 
#define FTP_CUST_RST_N         0x40
#define FTP_CUST_REQ           0x10
#define FTP_CUST_SECT          0x07
#define FTP_CTRL_1             0x97
#define FTP_CUST_SER           0xF8
#define FTP_CUST_OPCODE        0x07
#define RW_BUFFER              0x53
#define TX_HEADER_LOW          0x51
#define PD_COMMAND_CTRL        0x1A
#define DPM_PDO_NUMB           0x70

#define READ                   0x00
#define WRITE_PL               0x01
#define WRITE_SER              0x02
#define ERASE_SECTOR           0x05
#define PROG_SECTOR            0x06
#define SOFT_PROG_SECTOR       0x07

#define SECTOR_0               0x01
#define SECTOR_1               0x02
#define SECTOR_2               0x04
#define SECTOR_3               0x08
#define SECTOR_4               0x10