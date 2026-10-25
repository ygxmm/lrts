TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = lazyaudio
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LazyAudioNoSplash
LazyAudioNoSplash_FILES = Tweak.x
LazyAudioNoSplash_CFLAGS = -fobjc-arc
LazyAudioNoSplash_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
