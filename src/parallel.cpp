#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <numeric>
#include <fstream>
#include <random>
#include <limits>
#ifdef _OPENMP
  #include <omp.h>
#endif
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
            edges.reserve(m); //prevents allocations afterwards
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
    vector<int> deg(n, 0);
    for (auto &e : edges) { deg[e.first]++; deg[e.second]++; }

    adj.assign(n, {});
    for (int i = 0; i < n; ++i) adj[i].reserve(deg[i]);

    for (auto &e : edges) {
        adj[e.first].push_back(e.second);
        adj[e.second].push_back(e.first);
    }
    for (int i = 0; i < n; ++i) {
        auto &nbr = adj[i];
        sort(nbr.begin(), nbr.end()); //sort neighbors so duplicates become adjacent
        nbr.erase(unique(nbr.begin(), nbr.end()), nbr.end()); // drop multiedges, unique moves duplicates to start
    }
    return true;

    // after reading all edges
}

// ---- DOT writer ------
void write_dot(const string& path, const vector<vector<int>>& adj, const vector<int>& color) {
    static const vector<string> pal = {
        "red","green","blue","gold","cyan","magenta","orange","purple","brown","pink",
        "gray","turquoise","violet","chartreuse","salmon","tan","sienna","khaki","aquamarine","orchid"
    };
    int n = (int)adj.size();
    ofstream out(path); //open out file streat
    if (!out) {cerr << "Cannot open DOT output path.\n"; return; }
    out << "graph G {\n";
    out << "  layout=neato;\n  overlap=false;\n  splines=true;\n";
    out << "  node [shape=circle, style=filled, fontname=Inter];\n";

    // convert vertices indices back to 1-based like in dimacs
    for (int v=0; v<n; ++v) {
        int c = color[v];
        string fill = pal[c % pal.size()];
        out << "  " << (v+1) << " [label=\"" << (v+1) << "\", fillcolor=\"" << fill << "\", tooltip=\"v"
            << (v+1) << " color " << c << "\"];\n";
    }
    // each undirected edge once
    for (int u=0; u<n; ++u) {
        for (int v: adj[u]) {
            if (u < v) {
                out << "  " << (u+1) << " -- " << (v+1) << ";\n";
            } 
        }
    }
    out << "}\n";
    cerr << "DOT written to: " << path << "\n";
}


// ---- Build a MIS using Luby ----
static void build_mis_luby(const vector<vector<int>>& adj,
                                   const vector<char>& U, //vertices allowed
                                   vector<int>& mis)
{
    const int n = (int)adj.size();
    vector<char> active(n, 0);
    int active_cnt = 0;
    for (int i=0; i<n; ++i){
         if (U[i]) { active[i]=1; active_cnt++; }
    }
    mis.clear();
    if (active_cnt==0) return; //done

    vector<int> deg(n,0); //only active neighbors degree
    vector<char> cand(n,0), drop(n,0), keep(n,0);

    while (active_cnt > 0) {
        // current degrees in induced subgraph
        #pragma omp parallel for schedule(dynamic, 1024) //this loop parallel across threads
        for (int v=0; v<n; ++v){
            if (active[v]) {
                int d=0;
                for (int u: adj[v]) if (active[u]) d++;
                deg[v]=d;
            }
        }

        // sampling U
        #pragma omp parallel
        {
            std::random_device rd;
            std::mt19937_64 gen(rd() ^ (uint64_t)omp_get_thread_num()); //rng, so each thread has indep. randomness
            std::uniform_real_distribution<double> dis(0.0,1.0);
            #pragma omp for schedule(static) //parallel loop
            for (int v=0; v<n; ++v) if (active[v]) {
                int d = deg[v];
                double p = (d==0) ? 1.0 : 1.0 / (2.0 * d); //cand[v] ~ Bernoulli( 1/(2*deg[v]) ), with p=1 for deg=0
                cand[v] = dis(gen) < p ? 1 : 0; //decide which candidates based on proba
            }
        }

        // resolve conflicts inside U
        #pragma omp parallel for schedule(dynamic, 1024)
        for (int v=0; v<n; ++v) if (active[v] && cand[v]) {
            bool lose = false;
            for (int u: adj[v]) if (active[u] && cand[u]) {
                if (deg[v] < deg[u] || (deg[v]==deg[u] && v < u)) { lose = true; break; }
            }
            drop[v] = lose ? 1 : 0;
        }

        // finalize U
        vector<int> U_kept;
        U_kept.reserve(active_cnt); //prealocating memory for efficiency
        for (int v=0; v<n; ++v) if (active[v] && cand[v] && !drop[v]) {
            keep[v] = 1;
            U_kept.push_back(v);
            mis.push_back(v); // accumulate for MIS
        }

        // deactivate U and their neighbors
        vector<char> next_active = active;
        #pragma omp parallel for schedule(dynamic, 1024)
        for (int v=0; v<n; ++v) if (keep[v]) {
            next_active[v] = 0;
            for (int u: adj[v]) {
                #pragma omp atomic write //race-free, but every thread writes just zeros anyway
                next_active[u] = 0;
            }
        }

        int cnt=0;
        #pragma omp parallel for reduction(+:cnt) //shared, each thread adds local partial sum
        for (int v=0; v<n; ++v) cnt += next_active[v];
        active.swap(next_active);
        active_cnt = cnt;

        // clear flags
        #pragma omp parallel for schedule(static)
        for (int v=0; v<n; ++v) { cand[v]=0; drop[v]=0; keep[v]=0; }
    }
}

// ---- Coloring round of MIS ----
vector<int> color_luby_parallel(const vector<vector<int>>& adj) {
    const int n = (int)adj.size();
    vector<int> color(n, -1);
    vector<char> uncolored(n, 1);

    int left = n, cur = 0;
    while (left > 0) {
        vector<int> S;
        build_mis_luby(adj, uncolored, S);

        #pragma omp parallel for schedule(static)
        for (int i=0; i<(int)S.size(); ++i) color[S[i]] = cur;

        for (int v: S) if (uncolored[v]) { uncolored[v]=0; left--; }
        cur++;
    }
    return color;
}

// ---- Main ----
int main(int argc, char** argv) {
    string dot_path = "graph_colored.dot";
    for (int i=1; i<argc; ++i) {
        string a = argv[i];
        if (a == "--dot" && i+1 < argc) dot_path = argv[++i];
        else if (a == "--help" || a == "-h") {
            cerr << "Usage: parallel [--dot out.dot] < input.col\n";
            return 0;
        }
    }

    int n, m;
    vector<vector<int>> adj;
    if (!read_dimacs(n, m, adj)) { cerr << "Failed to read DIMACS from input.\n"; return 1; }

    vector<int> color = color_luby_parallel(adj);

    int k = 0; for (int c: color) k = max(k, c+1);
    cout << "colors_used: " << k << "\n";
    write_dot(dot_path, adj, color);
    return 0;
}
