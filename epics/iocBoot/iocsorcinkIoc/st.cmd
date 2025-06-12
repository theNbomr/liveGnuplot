#!../../bin/linux-x86_64/sorcinkIoc

#- SPDX-FileCopyrightText: 2005 Argonne National Laboratory
#-
#- SPDX-License-Identifier: EPICS

#- You may have to change sorcinkIoc to something else
#- everywhere it appears in this file

#< envPaths

## Register all support components
dbLoadDatabase "../../dbd/sorcinkIoc.dbd"
sorcinkIoc_registerRecordDeviceDriver(pdbbase) 

## Load record instances
#dbLoadRecords("../../db/sorcinkIoc.db","user=bomr")
dbLoadRecords("../../db/sorcink.db")

iocInit()

## Start any sequence programs
#seq sncsorcinkIoc,"user=bomr"
