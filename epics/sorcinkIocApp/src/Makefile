# SPDX-FileCopyrightText: 2003 Argonne National Laboratory
#
# SPDX-License-Identifier: EPICS

TOP=../..

include $(TOP)/configure/CONFIG
#----------------------------------------
#  ADD MACRO DEFINITIONS AFTER THIS LINE
#=============================

#=============================
# Build the IOC application

PROD_IOC = sorcinkIoc
# sorcinkIoc.dbd will be created and installed
DBD += sorcinkIoc.dbd

# sorcinkIoc.dbd will be made up from these files:
sorcinkIoc_DBD += base.dbd

# Include dbd files from all support applications:
#sorcinkIoc_DBD += xxx.dbd

# Add all the support libraries needed by this IOC
#sorcinkIoc_LIBS += xxx

# sorcinkIoc_registerRecordDeviceDriver.cpp derives from sorcinkIoc.dbd
sorcinkIoc_SRCS += sorcinkIoc_registerRecordDeviceDriver.cpp

# Build the main IOC entry point on workstation OSs.
sorcinkIoc_SRCS_DEFAULT += sorcinkIocMain.cpp
sorcinkIoc_SRCS_vxWorks += -nil-

# Add support from base/src/vxWorks if needed
#sorcinkIoc_OBJS_vxWorks += $(EPICS_BASE_BIN)/vxComLibrary

# Finally link to the EPICS Base libraries
sorcinkIoc_LIBS += $(EPICS_BASE_IOC_LIBS)

#===========================

include $(TOP)/configure/RULES
#----------------------------------------
#  ADD RULES AFTER THIS LINE

