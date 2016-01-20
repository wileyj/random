CXX      := g++
RFLAGS   := -I/usr/include/hiredis -I/usr/include
#MFLAGS   := -I/usr/include/libbson-1.0 -I/usr/include/libmongoc-1.0 -I/usr/include
CXXFLAGS := 
MLDFLAGS := -L/usr/lib64 -L/lib64 -L/usr/lib -lmongoc
RLDFLAGS := -L/usr/lib64 -L/lib64 -L/usr/lib -lhiredis
MINSERT  := m_insert
MINDEX   := m_index
MQUERY   := m_query
RQUERY   := r_query
RINSERT  := r_insert
INSERT   := insert


mongo:
	 $(CXX) $(MFLAGS) $(CXXFLAGS) $(MLDFLAGS) mongodb.c -o $(MQUERY)
	 $(CXX) $(MFLAGS) $(CXXFLAGS) $(MLDFLAGS) mongodb-index.c -o $(MINDEX)
	 $(CXX) $(MFLAGS) $(CXXFLAGS) $(MLDFLAGS) mongodb-insert.c -o $(MINSERT)

redis:
	$(CXX) $(RFLAGS) $(CXXFLAGS) $(RLDFLAGS) redis.c -o $(RQUERY)
	$(CXX) $(RFLAGS) $(CXXFLAGS) $(RLDFLAGS) redis-insert.c -o $(RINSERT)

clean:
	rm -rf $(MQUERY) $(MINDEX) $(MINSERT) $(RQUERY) $(RQUERY) $(INSERT)

clean-insert:
	rm -rf insert

insert:
	$(CXX) $(CXXFLAGS) $(RFLAGS) $(RLDFLAGS) $(MLDFLAGS) insert.cpp -o $(INSERT)

all:
	make clean
	make mongo
	make redis
	make insert
