cmake_minimum_required(VERSION 3.22.1)
project("nng_probe")

add_library(nng_probe SHARED src/main/cpp/nng_probe.c)
target_link_libraries(nng_probe log dl)
