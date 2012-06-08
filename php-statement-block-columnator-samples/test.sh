#!/bin/bash

for i in *.php
do 
   echo $i 
   echo "=================================================================================" 
   cat $i
   echo ""
   echo "---------------------------------------------------------------------------------" 
   ruby ../php-statement-block-columnator.rb <$i 
   echo ""
   echo ""
   echo ""
done
