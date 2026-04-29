transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+mig  -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.mig xil_defaultlib.glbl

do {mig.udo}

run 1000ns

endsim

quit -force
