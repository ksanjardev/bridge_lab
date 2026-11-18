cmake_minimum_required(VERSION 3.18.1)
project(image_lab C)

add_library(image_lab SHARED image_lab.c)

# Debug builds default to -O0, which would make the comparison unfair to C.
target_compile_options(image_lab PRIVATE -O3)

# Google Play requires 16 KB page alignment for apps targeting Android 15+.
target_link_options(image_lab PRIVATE "-Wl,-z,max-page-size=16384")