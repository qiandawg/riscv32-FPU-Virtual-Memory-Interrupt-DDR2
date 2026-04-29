#include "mfp_io.h"

int main ()
{
	// enable right-most 7-segment display digit
	MFP_7SEGEN = 0xFE;  

    while (1) {
        MFP_LEDS          = MFP_LIGHTSENSOR >> 4;
        MFP_7SEGDIGITS    = MFP_LIGHTSENSOR;
    }

    return 0;
}
