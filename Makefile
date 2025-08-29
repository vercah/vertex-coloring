APP ?= build/greedy
SRC ?= src/greedy.cpp

CXX ?= g++
CXXFLAGS ?= -O2 -g -fno-omit-frame-pointer -Wall -Wextra

all: $(APP)

$(APP): $(SRC)
	mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -f $(APP) runs.csv summary.csv
