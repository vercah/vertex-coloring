#include <bits/stdc++.h>
using namespace std;

// ---------- DIMACS reader (stdin) ----------
bool read_dimacs(int& n, int& m, vector<vector<int>>& adj) {
    ios::sync_with_stdio(false); //disconnects c++ from c (scanf, printf), to make it faster
    cin.tie(nullptr); // stops cin from flusing cout before reading
    n = m = -1;
    string line;
    vector<pair<int,int>> edges;
    while (true) {
        string t;
        if(!(cin >> t)) break;
        if (t == "c") {
            getline(cin, line); //skip commentline
        } else if (t == "p") {
            string kind;
            cin >> kind >> n >> m;
            if (n <= 0) return false;
            adj.assign(n, {}); //reset adjacency table
        } else if (t == "e") {
            int a, b;
            cin >> a >> b;
            if (n <= 0) { cerr << "Missing 'p' line before edge declaration in the DIMACS file.\n"; return false;}
            if (a == b) continue; // ignore self-loops
            if (a < 1 || a > n || b < 1 || b > n) { cerr << "Edge out of range.\n"; return false;}
            edges.emplace_back(a-1,b-1);   //convert to 0-based and store
        } else {
            //unknown token, continue
            getline(cin, line);
        }
    }
    if (n <= 0) return false;

    // building adjacency, deduplication of multiedges
    vector<unordered_set<int>> tmp(n); //store only unique integers
    for (unsigned int i = 0; i < edges.size(); ++i) {
        int u = edges[i].first;
        int v = edges[i].second;
        tmp[u].insert(v);
        tmp[v].insert(u);
    }
    adj.assign(n, {});
    for (int i=0;i<n;++i) {
        adj[i] = vector<int>(tmp[i].begin(), tmp[i].end());
    } 
    return true;
}