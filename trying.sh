#!/bin/bash

a=($(head -1 /proc/stat)); sleep 1; b=($(head -1 /proc/stat))
ta=$((a[1]+a[2]+a[3]+a[4]+a[5]+a[6]+a[7]+a[8]))
tb=$((b[1]+b[2]+b[3]+b[4]+b[5]+b[6]+b[7]+b[8]))
ia=$((a[4]+a[5])); ib=$((b[4]+b[5]))
dt=$((tb-ta)); di=$((ib-ia))
echo "ticks elapsed: $dt   idle ticks: $di"
echo "CPU busy: $(( 100*(dt-di)/dt ))%"
