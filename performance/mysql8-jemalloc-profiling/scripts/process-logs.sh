#!/bin/bash
for file in *run*log; do
  grep ".*,.*,.*," $file > $file.processed.csv
  awk '/SQL statistics/,0' $file > $file.stats
done
for file in *processed.csv; do
  label=$(echo "${file}" | awk -F'.' '{print $1}')
  test_type=$(echo "${file}" | awk -F'.' '{print $3}')
  test_threads=$(echo "${file}" | awk -F'.' '{print $4}')
  mv "${file}" "${label}.${test_type}.${test_threads}.csv"
done
for file in *.log.stats; do
  label=$(echo "${file}" | awk -F'.' '{print $1}')
  test_type=$(echo "${file}" | awk -F'.' '{print $3}')
  test_threads=$(echo "${file}" | awk -F'.' '{print $4}')
  mv "${file}" "${label}.${test_type}.${test_threads}.stats"
done
#for i in {16,64,128,256,512,1024,1536}; do
#  gnuplot -c gnuplot.script in-memory_${i}.arm.csv in-memory_${i}.x86.csv ${i} in-memory In-Memory
#  gnuplot -c gnuplot.script io-bound_${i}.arm.csv io-bound_${i}.x86.csv ${i} io-bound IO-bound
#done
#gnuplot -c gnuplot.all-tests.script in-memory_16.x86.csv in-memory_32.x86.csv in-memory_64.x86.csv in-memory_128.x86.csv in-memory In-Memory m5d.8xlarge
#gnuplot -c gnuplot.all-tests.script in-memory_16.arm.csv in-memory_32.arm.csv in-memory_64.arm.csv in-memory_128.arm.csv in-memory In-Memory m6gd.8xlarge
#gnuplot -c gnuplot.all-tests.script io-bound_16.x86.csv io-bound_32.x86.csv io-bound_64.x86.csv io-bound_128.x86.csv io-bound IO-bound m5d.8xlarge
#gnuplot -c gnuplot.all-tests.script io-bound_16.arm.csv io-bound_32.arm.csv io-bound_64.arm.csv io-bound_128.arm.csv io-bound IO-bound m6gd.8xlarge
