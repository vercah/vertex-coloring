#include <bits/stdc++.h>
using namespace std;

// ---- DIMACS reader ----
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

// ---- Greedy coloring ------
vector<int> greedy_color(const vector<vector<int>>& adj, const vector<int>& order) {
    int n = (int)adj.size();
    vector<int> color(n, -1), mark(n, -1); // n colors, initially -1; mark tracks forbidden colors
    int stamp = 0; //timestamp to avoid clearing mark each time
    for (int v : order) {
        stamp++;
        for (int u : adj[v]) { if (color[u] != -1) mark[color[u]] = stamp;}
        int c = 0;
        while (c < n && mark[c] == stamp) c++;
        color[v] = c;
    }
    return color;
}

// sort vertices by descending degree and vertex id
vector<int> desc_degree_order(const vector<vector<int>>& adj) {
    int n = (int)adj.size();
    vector<int> order(n);
    iota(order.begin(), order.end(), 0);  // fill with 0..n-1
    sort(order.begin(), order.end(), [&](int a, int b) { //capture by reference from adj
        if (adj[a].size() != adj[b].size())
            return adj[a].size() > adj[b].size(); // higher degree first
        return a < b; // tie: smaller index first
    });
    return order;
}

// ---- Main ------
// uses the welsh-powell algo
int main(int argc, char** argv) {
    string dot_path = "graph_colored.dot"; //default
    for (int i=1; i<argc; ++i) { //arg[0] is program name
        string a = argv[i];
        if (a == "--dot" && i+1 < argc) { dot_path = argv[++i]; } //user dot filename
        else if (a == "--help" || a == "-h") {
            cerr << "Usage: color [--dot out.dot] < input.col\n";
            return 0;
        }
    }

    int n, m;
    vector<vector<int>> adj;
    if (!read_dimacs(n, m, adj)) { cerr << "Failed to read DIMACS from input file.\n"; return 1; }

    vector<int> order = desc_degree_order(adj);

    vector<int> color = greedy_color(adj, order);

    int k = 0;
    for (int c: color) {k = max(k, c+1);}
    cout << k << "\n"; // number of colors used
    for (int i=0; i<n; ++i) { cout << color[i] << (i+1==n ? '\n':' ');}

}