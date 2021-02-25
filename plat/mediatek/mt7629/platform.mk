#
# Copyright (c) 2020, MediaTek Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

AARCH32_SP		:=	sp_min
ARM_CORTEX_A7		:=	yes
ARM_ARCH_MAJOR		:=	7
MARCH32_DIRECTIVE	:=	-mcpu=cortex-a7 -msoft-float
BL2_AT_EL3		:=	1

# Not needed for Cortex-A7
WORKAROUND_CVE_2017_5715:=	0

MTK_PLAT		:=	plat/mediatek
MTK_PLAT_SOC		:=	${MTK_PLAT}/${PLAT}

PLAT_INCLUDES		:=	-I${MTK_PLAT}/common/				\
				-I${MTK_PLAT}/common/drivers/uart		\
				-Iinclude/plat/arm/common			\
				-I${MTK_PLAT_SOC}/drivers/pinctrl/		\
				-I${MTK_PLAT_SOC}/drivers/pll/			\
				-I${MTK_PLAT_SOC}/drivers/spm/			\
				-I${MTK_PLAT_SOC}/drivers/timer/		\
				-I${MTK_PLAT_SOC}/include/

PLAT_BL_COMMON_SOURCES	:=	lib/xlat_tables/xlat_tables_common.c		\
				lib/xlat_tables/aarch32/xlat_tables.c		\
				lib/cpus/aarch32/cortex_a7.S			\
				${MTK_PLAT}/common/drivers/uart/aarch32/hsuart.S	\
				drivers/delay_timer/delay_timer.c		\
				drivers/delay_timer/generic_delay_timer.c	\
				${MTK_PLAT}/common/mtk_plat_common.c		\
				${MTK_PLAT_SOC}/aarch32/plat_helpers.S		\
				${MTK_PLAT_SOC}/aarch32/platform_common.c

BL2_SOURCES		:=	common/desc_image_load.c			\
				drivers/gpio/gpio.c				\
				drivers/io/io_storage.c				\
				drivers/io/io_block.c				\
				drivers/io/io_fip.c				\
				${MTK_PLAT_SOC}/bl2_plat_setup.c		\
				${MTK_PLAT_SOC}/drivers/pinctrl/pinctrl.c	\
				${MTK_PLAT_SOC}/drivers/pll/pll.c		\
				${MTK_PLAT_SOC}/drivers/spm/spmc.c		\
				${MTK_PLAT_SOC}/drivers/timer/cpuxgpt.c

ifndef BOOT_DEVICE
$(error You must specify the boot device by provide BOOT_DEVICE= to \
	make parameter. Avaliable values: nor snand)
else
ifeq ($(BOOT_DEVICE),ram)
BL2_SOURCES		+=	drivers/io/io_memmap.c				\
				${MTK_PLAT_SOC}/bl2_boot_ram.c
BROM_HEADER_TYPE	:=	nor
ifeq ($(RAM_BOOT_DEBUGGER_HOOK), 1)
CPPFLAGS		+=	-DRAM_BOOT_DEBUGGER_HOOK
endif
endif
ifeq ($(BOOT_DEVICE),nor)
BL2_SOURCES		+=	drivers/io/io_memmap.c				\
				${MTK_PLAT_SOC}/bl2_boot_nor.c
BROM_HEADER_TYPE	:=	nor
endif
ifeq ($(BOOT_DEVICE),snand)
include ${MTK_PLAT}/common/drivers/snfi/mtk-snand.mk
BROM_HEADER_TYPE	:=	snand
NAND_TYPE		?=	2k+64
BL2_SOURCES		+=	${MTK_SNAND_SOURCES}				\
				${MTK_PLAT_SOC}/bl2_boot_snand.c
PLAT_INCLUDES		+=	-I${MTK_PLAT}/common/drivers/snfi
CPPFLAGS		+=	-DMTK_MEM_POOL_BASE=0x40100000			\
				-DPRIVATE_MTK_SNAND_HEADER
endif
ifeq ($(BROM_HEADER_TYPE),)
$(error BOOT_DEVICE has invalid value. Please re-check.)
endif
endif

BL2_BASE		:=	0x201000
CPPFLAGS		+=	-DBL2_BASE=$(BL2_BASE) -D__SOFTFP__

DOIMAGEPATH		:=	tools/mediatek/bromimage
DOIMAGETOOL		:=	${DOIMAGEPATH}/bromimage

# indicate the reset vector address can be programmed
PROGRAMMABLE_RESET_ADDRESS	:=	1

$(eval $(call add_define,MTK_SIP_SET_AUTHORIZED_SECURE_REG_ENABLE))

BL32_SOURCES		+=	drivers/arm/cci/cci.c				\
				drivers/arm/gic/common/gic_common.c		\
				drivers/arm/gic/v2/gicv2_main.c			\
				drivers/arm/gic/v2/gicv2_helpers.c		\
				plat/common/plat_gicv2.c			\
				plat/common/plat_psci_common.c	\
				${MTK_PLAT}/common/mtk_sip_svc.c		\
				${MTK_PLAT_SOC}/drivers/spm/spmc.c		\
				${MTK_PLAT_SOC}/plat_sip_calls.c		\
				${MTK_PLAT_SOC}/plat_topology.c		\
				${MTK_PLAT_SOC}/plat_pm.c		\
				${MTK_PLAT_SOC}/plat_mt_gic.c

# Do not enable SVE
ENABLE_SVE_FOR_NS		:=	0
MULTI_CONSOLE_API		:=	1

ifneq (${TRUSTED_BOARD_BOOT},0)

include drivers/auth/mbedtls/mbedtls_crypto.mk
include drivers/auth/mbedtls/mbedtls_x509.mk
ifeq ($(MBEDTLS_DIR),)
$(error You must specify MBEDTLS_DIR when TRUSTED_BOARD_BOOT enabled)
endif

AUTH_SOURCES		:=	drivers/auth/auth_mod.c		\
				drivers/auth/crypto_mod.c	\
				drivers/auth/img_parser_mod.c	\
				drivers/auth/tbbr/tbbr_cot_bl2.c	\
				drivers/auth/tbbr/tbbr_cot_common.c	\
				$(MBEDTLS_DIR)/library/md_wrap.c

BL2_SOURCES		+=	${AUTH_SOURCES}			\
				plat/common/tbbr/plat_tbbr.c	\
				${MTK_PLAT_SOC}/mtk_tbbr.c	\
				${MTK_PLAT_SOC}/mtk_rotpk.S

ROT_KEY			=	$(BUILD_PLAT)/rot_key.pem
ROTPK_HASH		=	$(BUILD_PLAT)/rotpk_sha256.bin

$(eval $(call add_define_val,ROTPK_HASH,'"$(ROTPK_HASH)"'))
$(BUILD_PLAT)/bl1/mtk_rotpk.o: $(ROTPK_HASH)
$(BUILD_PLAT)/bl2/mtk_rotpk.o: $(ROTPK_HASH)

certificates: $(ROT_KEY)
$(ROT_KEY): | $(BUILD_PLAT)
	@echo "  OPENSSL $@"
	$(Q)openssl genrsa 2048 > $@ 2>/dev/null

$(ROTPK_HASH): $(ROT_KEY)
	@echo "  OPENSSL $@"
	$(Q)openssl rsa -in $< -pubout -outform DER 2>/dev/null |\
	openssl dgst -sha256 -binary > $@ 2>/dev/null
endif

all: $(BUILD_PLAT)/bl2.img

ifneq ($(USE_MKIMAGE),1)
ifneq ($(BROM_SIGN_KEY),)
$(BUILD_PLAT)/bl2.img: $(BROM_SIGN_KEY)
endif

$(BUILD_PLAT)/bl2.img: $(BUILD_PLAT)/bl2.bin $(DOIMAGETOOL)
	-$(Q)rm -f $@.signkeyhash
	$(Q)$(DOIMAGETOOL) -f $(BROM_HEADER_TYPE) -a $(BL2_BASE) -d		\
		$(if $(BROM_SIGN_KEY), -s sha256+rsa-m1 -k $(BROM_SIGN_KEY))	\
		$(if $(BROM_SIGN_KEY), -p $@.signkeyhash)			\
		$(if $(DEVICE_HEADER_OFFSET), -o $(DEVICE_HEADER_OFFSET))	\
		$(if $(NAND_TYPE), -n $(NAND_TYPE))				\
		$(BUILD_PLAT)/bl2.bin $@
else
MKIMAGE ?= mkimage

ifneq ($(BROM_SIGN_KEY),)
$(warning BL2 signing is not supported using mkimage)
endif

$(BUILD_PLAT)/bl2.img: $(BUILD_PLAT)/bl2.bin
	$(Q)$(MKIMAGE) -T mtk_image -a $(BL2_BASE) -e $(BL2_BASE)		\
		-n "media=$(BROM_HEADER_TYPE)$(if $(NAND_TYPE),;nandinfo=$(NAND_TYPE))"	\
		-d $(BUILD_PLAT)/bl2.bin $@
endif

.PHONY: $(BUILD_PLAT)/bl2.img

distclean realclean clean: cleandoimage

cleandoimage:
	$(Q)$(MAKE) --no-print-directory -C $(DOIMAGEPATH) clean

$(DOIMAGETOOL):
	$(Q)$(MAKE) --no-print-directory -C $(DOIMAGEPATH)
