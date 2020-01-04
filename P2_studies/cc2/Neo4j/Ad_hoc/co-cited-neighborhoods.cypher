// |N(xy) = Co-citing set|/|NxUNy = N*(x) union with N*(y)|
MATCH (x:Publication {node_id: '17538003'})<--(Nxy)-->(y:Publication {node_id: '18983824'})
WITH count(Nxy) AS cnxy, x, y
MATCH (x)<--(Nx)
WITH collect(Nx) AS nx_list, cnxy, y
MATCH (y)<--(Ny)
WITH nx_list + collect(Ny) AS NxUNy_list, cnxy
UNWIND NxUNy_list AS NxUNy
WITH toFloat(cnxy) / count(DISTINCT NxUNy) AS intersect_to_union_ratio
// E(x,y)/(|N(x)|*|N(y)|)
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
WITH min(toInteger(Nxy.pub_year)) AS first_co_citation_year, x, y, intersect_to_union_ratio
MATCH (Nx:Publication)-->(x)
  WHERE toInteger(Nx.pub_year) <= first_co_citation_year
WITH count(Nx) AS cnx, first_co_citation_year, x, y, intersect_to_union_ratio
MATCH (Ny:Publication)-->(y)
  WHERE toInteger(Ny.pub_year) <= first_co_citation_year
WITH count(Ny) AS cny, cnx, first_co_citation_year, x, y, intersect_to_union_ratio
MATCH (x)<--(Ex:Publication)-[E]-(Ey:Publication)-->(y)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
RETURN toFloat(count(E)) / (cnx * cny) AS e_ratio, intersect_to_union_ratio;

// |N(xy) = Co-citing set|/|NxUNy = N*(x) union with N*(y)|: input from the DB
MATCH (x:Publication {node_id: $cited_1})<--(Nxy)-->(y:Publication {node_id: $cited_2})
WITH count(Nxy) AS cnxy, x, y
MATCH (x)<--(Nx)
WITH collect(Nx) AS nx_list, cnxy, y
MATCH (y)<--(Ny)
WITH nx_list + collect(Ny) AS NxUNy_list, cnxy
UNWIND NxUNy_list AS NxUNy
RETURN toFloat(cnxy) / count(DISTINCT NxUNy);

// |N(xy) = Co-citing set|/|NxUNy = N*(x) union with N*(y)|
MATCH (x:Publication {node_id: $cited_1})<--(Nxy)-->(y:Publication {node_id: $cited_2})
WITH count(Nxy) AS cnxy, x, y
MATCH (x)<--(Nx)
WITH collect(Nx) AS nx_list, cnxy, y
MATCH (y)<--(Ny)
WITH nx_list + collect(Ny) AS NxUNy_list, cnxy
UNWIND NxUNy_list AS NxUNy
RETURN toFloat(cnxy) / count(DISTINCT NxUNy);
//
//MATCH (x:Publication {node_id: ''})<--(Nxy)-->(y:Publication {node_id: ''})
/*
cited_1	cited_2     time (s)
474	    84870231656 0.9
2224	  1156126     0.7
2224	  33751141500 4.6s
4532	  320221      1.1s
4532	  371265      0.3s

9482260 14949207    0.02-2.6
*/

// |N(xy) = Co-citing set|/|NxUNy = N*(x) union with N*(y)|
// 0.02s-0.08s
MATCH (x:Publication {node_id: '17538003'})<--(Nxy)-->(y:Publication {node_id: '18983824'})
WITH count(Nxy) AS cnxy
MATCH (x:Publication {node_id: '17538003'})<--(Nx)
WITH collect(Nx) AS nx_list, cnxy
MATCH (y:Publication {node_id: '18983824'})<--(Ny)
WITH nx_list + collect(Ny) AS NxUNy_list, cnxy
UNWIND NxUNy_list AS NxUNy
RETURN toFloat(cnxy) / count(DISTINCT NxUNy);

// |NxUNy = N*(x) union with N*(y)|
// 0.7s
MATCH (x:Publication {node_id: '17538003'})<--(Nx)
WITH collect(Nx) AS nx_list
MATCH (y:Publication {node_id: '18983824'})<--(Ny)
WITH nx_list + collect(Ny) AS node_list
UNWIND node_list AS n
RETURN count(DISTINCT n);
// 907 = 792+177-62

// |NxUNy = N*(x) union with N*(y)|
// *runaway*
MATCH (NxUNy)
  WHERE exists((:Publication {node_id: '17538003'})<--(NxUNy)) OR exists((NxUNy)-->(:Publication {node_id: '18983824'}))
RETURN count(NxUNy);

// |N*(xy) = Co-citing set|
// 0.06s
MATCH (x:Publication {node_id: '17538003'})<--(Nxy)-->(y:Publication {node_id: '18983824'})
RETURN count(Nxy);
// 62

// E(x,y)/(|N(x)|*|N(y)|)
// 1.1s
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
WITH min(toInteger(Nxy.pub_year)) AS first_co_citation_year, x, y
MATCH (Nx:Publication)-->(x)
  WHERE toInteger(Nx.pub_year) <= first_co_citation_year
WITH count(Nx) AS cnx, first_co_citation_year, x, y
MATCH (Ny:Publication)-->(y)
  WHERE toInteger(Ny.pub_year) <= first_co_citation_year
WITH count(Ny) AS cny, cnx, first_co_citation_year, x, y
MATCH (x)<--(Ex:Publication)-[E]-(Ey:Publication)-->(y)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
RETURN toFloat(count(E)) / (cnx * cny);
// 0.08181818181818182

// |N(x)|
// 2.4s
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
WITH min(toInteger(Nxy.pub_year)) AS first_co_citation_year, x
MATCH (Nx:Publication)-->(x)
  WHERE toInteger(Nx.pub_year) <= first_co_citation_year
RETURN count(Nx);
// 22

// |N(y)|
// 0.04s
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
WITH min(toInteger(Nxy.pub_year)) AS first_co_citation_year, y
MATCH (Ny:Publication)-->(y)
  WHERE toInteger(Ny.pub_year) <= first_co_citation_year
RETURN count(Ny);
// 5

// E(x,y)
// 1.1s
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
WITH min(toInteger(Nxy.pub_year)) AS first_co_citation_year, x, y
OPTIONAL MATCH (x)<--(Ex:Publication)-[E]-(Ey:Publication)-->(y)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
WITH collect(E) AS edges, first_co_citation_year, x, y
OPTIONAL MATCH (x)<--(y)<-[E]-(Ey:Publication)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
WITH collect(E) + edges AS edges, first_co_citation_year, x, y
OPTIONAL MATCH (y)<--(x)<-[E]-(Ex:Publication)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
WITH collect(E) + edges AS edges
UNWIND edges AS edge
RETURN count(DISTINCT edge);
// 14

// E(x,y) on N*(x) and N*(y) result set
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
WITH min(toInteger(Nxy.pub_year)) AS first_co_citation_year, x, y
OPTIONAL MATCH (x)<--(Ex:Publication)-[E]-(Ey:Publication)-->(y)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
WITH collect(E) AS edges, first_co_citation_year, x, y
OPTIONAL MATCH (x)<--(y)<-[E]-(Ey:Publication)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
WITH collect(E) + edges AS edges, first_co_citation_year, x, y
OPTIONAL MATCH (y)<--(x)<-[E]-(Ex:Publication)
  WHERE toInteger(startNode(E).pub_year) <= first_co_citation_year
WITH collect(E) + edges AS edges
UNWIND edges AS edge
RETURN DISTINCT toInteger(startNode(edge).node_id), toInteger(endNode(edge).node_id);
// 14

// Year of the first co-citation
MATCH (x:Publication {node_id: '17538003'})<--(Nxy:Publication)-->(y:Publication {node_id: '18983824'})
RETURN min(toInteger(Nxy.pub_year));