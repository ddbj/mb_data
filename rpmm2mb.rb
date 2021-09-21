require 'rdf'
require 'rdf/turtle'
require 'json/ld'
require 'sparql'
require 'rdf/vocab'
require 'sparql/client'
require 'securerandom'
require 'uuid'

### new RDF
#graph_new = RDF::Graph.new
### from sparql endpoint
sparql = SPARQL::Client.new("https://mbs1.ddbj.nig.ac.jp/sparql")
### from file
#if argv = ARGV.shift  
#  repos = RDF::Repository.load(argv)
#  sparql = SPARQL::Client.new(repos)
#end

pmaps = {}
file = "projects-MTBKS-2021-09-14.ttl"
RDF::Reader.open(file) do |reader|
  reader.each_statement do |statement|
   #pid =  statement.subject.to_s.gsub('http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/','')
   pid =  statement.subject.to_s
   pmaps[pid] = statement.object.to_s
   #pp statement.inspect
   # graph_new << statement
  end
end
#pp pmaps
#exit

pfx = {
#  "": "http://ddbj.nig.ac.jp/resource/metabobank/",
#  "mb": "http://ddbj.nig.ac.jp/resource/metabobank/",
  "": "http://rdf.ddbj.nig.ac.jp/",
  "mb": "http://rdf.ddbj.nig.ac.jp/",
  "mbv": "http://ddbj.nig.ac.jp/ontologies/metabobank/",
  "ddbj": "http://ddbj.nig.ac.jp/ontologies/metabobank/",
#  "ddbj": "http://ddbj.nig.ac.jp/ontologies/core",
  "obo": "http://purl.obolibrary.org/obo/",
  "sio": "https://semanticscience.org/resource/"
}

query_projects ="
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT distinct ?s WHERE
{
  ?s rdf:type <http://metadb.riken.jp/ontology/plantMetabolomics/0.1/Project>.
  ?s ?p ?o.
}
"
def person uri
  uri.to_s.gsub('http://metadb.riken.jp/db/plantMetabolomics/0.1/Person/','').gsub(/([A-Z][a-z]+)([A-Z][a-z]+)/){ $1 + ' '+ $2 }
 end

sparql.query(query_projects).each do |prjs|
   ps = prjs[:s].to_s
   graph_new = RDF::Graph.new
   pid = pmaps[ps]
   
   query_project ="
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
#PREFIX pmm: <http://metadb.riken.jp/ontology/plantMetabolomics/0.1/>
SELECT * WHERE
{
  ?s rdf:type <http://metadb.riken.jp/ontology/plantMetabolomics/0.1/Project>.
  ?s ?p ?o.
#  FILTER( ?s = <http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/RPMM0001> ).
   FILTER( ?s = <#{ps}> ).
}
"


projects ={}
# {"http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/RPMM0001"=>
#   "3ee2d7f1-e933-4286-af89-002811fb4c53"}
sparql.query(query_project).each do |result|
      # ?s: http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/RPMM0001
      s = result[:s].to_s
      p =  result[:p].to_s
      unless projects.key?(s)
        projects[s] = pmaps[s] || SecureRandom.uuid
        subject = RDF::URI.new("#{pfx[:mb]}#{projects[s]}")
        graph_new << RDF::Statement.new(subject, RDF::RDFV.type,RDF::URI.new("#{pfx[:mbv]}Project") )
        graph_new << RDF::Statement.new(subject, RDF::URI.new("#{pfx[:ddbj]}dblink"), RDF::URI.new("#{subject}#dataset") )
        graph_new << RDF::Statement.new(subject, RDF::RDFS.seeAlso, result[:s])
      end
      subject = RDF::URI.new("#{pfx[:mb]}#{projects[s]}")
      #subject = RDF::URI.new("#{projects[s]}")
      case p
      when "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      when "http://www.w3.org/2000/01/rdf-schema#label"
        graph_new << RDF::Statement.new(subject, result[:p], result[:o])
      when "http://www.w3.org/2000/01/rdf-schema#seeAlso"
        graph_new << RDF::Statement.new(subject, result[:p], result[:o])
			when "http://xmlns.com/foaf/0.1/fundedBy"
        graph_new << RDF::Statement.new(subject, result[:p], result[:o])
			when "http://purl.org/dc/dcmitype/creator"
        graph_new << RDF::Statement.new(subject, RDF::Vocab::DC.creator, person(result[:o]))
			when "http://purl.org/dc/dcmitype/description"
        graph_new << RDF::Statement.new(subject, RDF::Vocab::DC.description, result[:o])
			when "http://purl.org/dc/dcmitype/identifier"
        graph_new << RDF::Statement.new(subject, RDF::Vocab::DC.identifier, projects[s]) ## MTBKS
        #graph_new << RDF::Statement.new(subject, RDF::URI.new("#{pfx[:ddbj]}primaryAccession"), result[:o])    ## TODO: biosample accession
        graph_new << RDF::Statement.new(subject, RDF::URI.new("#{pfx[:ddbj]}secondaryAccession"), projects[s]) ## MTBKS
			when "http://purl.org/dc/dcmitype/references"
        graph_new << RDF::Statement.new(subject, RDF::Vocab::DC.references, result[:o]) 
			when "http://metadb.riken.jp/ontology/plantMetabolomics/0.1/contactPerson"
        graph_new << RDF::Statement.new(subject,RDF::URI.new("#{pfx[:ddbj]}contactPerson") , person(result[:o]))
			when "http://metadb.riken.jp/ontology/plantMetabolomics/0.1/experiment"
        ## TODO dblink
			when "http://metadb.riken.jp/ontology/plantMetabolomics/0.1/principalInvestigator"
        graph_new << RDF::Statement.new(subject, RDF::URI.new("#{pfx[:ddbj]}principalInvestigator") , person(result[:o]))
			when "http://metadb.riken.jp/ontology/plantMetabolomics/0.1/submitter"
        graph_new << RDF::Statement.new(subject, RDF::URI.new("#{pfx[:ddbj]}submitter"),person(result[:o]) )
      when "http://www.w3.org/2000/01/rdf-schema#comment"
        #graph_new << RDF::Statement.new(subject, RDF::Vocab::DC.comment, result[:o])
        graph_new << RDF::Statement.new(subject, result[:p], result[:o])

      else
          warn "###project: " + result.inspect
      end

end

#puts graph_new.dump(:turtle, standard_prefixes: true, prefixes: pfx)
#exit

# Experiment
query_experiment ="
PREFIX mb: <http://metadb.riken.jp/ontology/plantMetabolomics/0.1/>
PREFIX dc: <http://purl.org/dc/dcmitype/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT
  ?uri as ?s ?p ?o ?id ?project_id ?project
FROM <http://metadb.riken.jp/db/plantMetabolomics>
WHERE {
    values ?type_uri {mb:Experiment}
    ?uri rdf:type ?type_uri.
    BIND(REPLACE(str(?uri),'http://metadb.riken.jp/db/plantMetabolomics/0.1/','') as ?id)
    ?type_uri rdfs:label ?type FILTER (lang(?type) = 'en').
    ?project (<>|!<>)* ?uri.
    ?project dc:identifier ?project_id.
    ?uri ?p ?o.
#    FILTER( ?project = <http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/RPMM0001> ).
    FILTER( ?project = <#{ps}> ).
}
"

#sparql.query(query_experiment).each do |result|
#    pp result.inspect
#end

exps ={}
exp_attrs = {}
cnt = 0
sparql.query(query_experiment).each do |result|
      #pp result.inspect
      puri = result[:project].to_s
      subject_p = RDF::URI.new("#{pfx[:mb]}#{projects[puri]}")
      subject_d = RDF::URI.new("#{pfx[:mb]}#{projects[puri]}#dataset")
      sid = result[:id].to_s
      unless exps.key?(sid)
        cnt = cnt + 1
        exps[sid] = "#{subject_p}-E#{cnt}"
        exp_attrs[sid] = 0
      end
#      cnt > 1 and next
      mtbks_id = "#{projects[puri]}-E#{cnt}"
      subject_s = RDF::URI.new(exps[sid])
      #graph_new << RDF::Statement.new(subject_s, RDF::RDFV.type,  RDF::URI.new("#{pfx[:mbv]}Experiment") )
      case result[:p].to_s
        when "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
            graph_new << RDF::Statement.new(subject_s, RDF::RDFV.type, RDF::URI.new("#{pfx[:mbv]}Experiment") )
        when "http://purl.org/dc/dcmitype/description"
            graph_new << RDF::Statement.new(subject_s, RDF::Vocab::DC.description, result[:o] || "")
        when "http://purl.org/dc/dcmitype/identifier"
            graph_new << RDF::Statement.new(subject_s, RDF::Vocab::DC.identifier, mtbks_id)
        when "http://www.w3.org/2000/01/rdf-schema#label"
            graph_new << RDF::Statement.new(subject_s, RDF::RDFS.label, result[:o] || "")
        when "http://metadb.riken.jp/ontology/plantMetabolomics/0.1/measurement"
            #warn result.inspect TODO: mesurement
        when /http:\/\/metadb.riken.jp\/ontology\/plantMetabolomics\/0.1\/(.+)/
          #puts "##" +  $1 + "\t" + result[:o].to_s
          #node = RDF::Node.uuid
          #node = RDF::URI.new("#{subject_s}/attr#{exp_attrs[sid].succ}")
          node = RDF::URI.new("#{subject_s}/attr##{$1}")
          graph_new << RDF::Statement.new(subject_s, RDF::URI.new("#{pfx[:sio]}SIO_000008"), node )
          graph_new << RDF::Statement.new(node, RDF::RDFV.type,  RDF::URI.new("#{pfx[:mbv]}ExperimentAttribute") )
          graph_new << RDF::Statement.new(node, RDF::RDFS.label, "#{$1}" )
          graph_new << RDF::Statement.new(node, RDF::URI.new("#{pfx[:sio]}SIO_000300"),  result[:o].to_s )
        else
          warn "###exp: " + result[:p]
      end      
end

#puts graph_new.dump(:turtle, standard_prefixes: true, prefixes: pfx)
#exit

# Sample
query_sample ="
PREFIX mb: <http://metadb.riken.jp/ontology/plantMetabolomics/0.1/>
PREFIX dc: <http://purl.org/dc/dcmitype/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT
  ?sample_uri as ?s ?p ?o ?sample_id ?project_id ?project
FROM <http://metadb.riken.jp/db/plantMetabolomics>
WHERE {
    values ?type_uri {mb:BiologicalSample}
    ?sample_uri rdf:type ?type_uri.
    BIND(REPLACE(str(?sample_uri),'http://metadb.riken.jp/db/plantMetabolomics/0.1/','') as ?sample_id)
    ?type_uri rdfs:label ?type FILTER (lang(?type) = 'en').
    #OPTIONAL {
    #    ?sample_uri rdfs:label ?label.
    #    BIND( str(?label) as ?name)
    #}
    ?project (<>|!<>)* ?sample_uri.
    ?project dc:identifier ?project_id.
    ?sample_uri ?p ?o.
#    FILTER( ?project = <http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/RPMM0001> ).
    FILTER( ?project = <#{ps}> ).
}
"

#sparql.query(query_sample).each do |result|
#    pp result.inspect
#end

samples ={}
sample_attrs = {}
cnt = 0
sparql.query(query_sample).each do |result|
      ##pp result.inspect
      puri = result[:project].to_s
      subject_p = RDF::URI.new("#{pfx[:mb]}#{projects[puri]}")
      subject_d = RDF::URI.new("#{pfx[:mb]}#{projects[puri]}#dataset")
      sid = result[:sample_id].to_s
      unless samples.key?(sid)
        cnt = cnt + 1
        samples[sid] = "#{subject_p}-S#{cnt}"
        #subject_s = RDF::URI.new("#{subject_p}#S#{cnt}")
        #subject_s = RDF::URI.new("#{subject_p}#S#{cnt}")
        sample_attrs[sid] = 0
      end
#      cnt > 1 and next
      subject_s = RDF::URI.new(samples[sid])
      mtbks_id = "#{projects[puri]}-S#{cnt}"
      graph_new << RDF::Statement.new(subject_s, RDF::RDFV.type,  RDF::URI.new("#{pfx[:mbv]}Sample") )
      case result[:p].to_s
        when "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
          graph_new << RDF::Statement.new(subject_s, RDF::RDFV.type, RDF::URI.new("#{pfx[:mbv]}Sample") )          
        when "http://purl.obolibrary.org/obo/RO_0002162"
          graph_new << RDF::Statement.new(subject_s, result[:p], RDF::URI.new(result[:o].to_s.gsub("http://purl.bioontology.org/ontology/NCBITAXON/","http://identifiers.org/taxonomy/")))          
          #  pp result.inspect
        when "http://purl.org/dc/dcmitype/identifier"
          graph_new << RDF::Statement.new(subject_s, RDF::Vocab::DC.identifier, mtbks_id)          
        when "http://www.w3.org/2000/01/rdf-schema#label"
          graph_new << RDF::Statement.new(subject_s, RDF::RDFS.label, result[:o] || "")          
        when /http:\/\/metadb.riken.jp\/ontology\/plantMetabolomics\/0.1\/(.+)/
          #puts "##" +  $1 + "\t" + result[:o].to_s
          #node = RDF::Node.uuid
          #node = RDF::URI.new("#{subject_s}/attr#{sample_attrs[sid].succ}")
          node = RDF::URI.new("#{subject_s}/attr##{$1}")
          graph_new << RDF::Statement.new(subject_s, RDF::URI.new("#{pfx[:sio]}SIO_000008"), node )
          graph_new << RDF::Statement.new(node, RDF::RDFV.type,  RDF::URI.new("#{pfx[:mbv]}SampleAttribute") )
          graph_new << RDF::Statement.new(node, RDF::RDFS.label, "#{$1}" )
          graph_new << RDF::Statement.new(node, RDF::URI.new("#{pfx[:sio]}SIO_000300"),  result[:o].to_s )
        else
          warn "###sample: " + result[:p]
      end      
end


#puts graph_new.dump(:turtle, standard_prefixes: true, prefixes: pfx)
#exit

# File
query_file ="
    PREFIX mb: <http://metadb.riken.jp/ontology/plantMetabolomics/0.1/>
    PREFIX dc: <http://purl.org/dc/dcmitype/>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    SELECT
      ?project
      ?file_id
      ?format
      ?md5
      ?project_id
      ?download_url
      ?name
      ?description 
    FROM <http://metadb.riken.jp/db/plantMetabolomics>
    WHERE {
        ?file_uri mb:fileFormat ?fileFormat.
        BIND(str(?fileFormat) as ?format)
        BIND(REPLACE(str(?file_uri),'http://metadb.riken.jp/db/plantMetabolomics/0.1/','') as ?file_id)
        ?file_uri rdf:type ?type_uri.
        ?type_uri rdfs:label ?type FILTER (lang(?type) = 'en').
        OPTIONAL {
            ?file_uri rdfs:label ?label.
            BIND( str(?label) as ?name)
        }
        OPTIONAL {
            ?file_uri mb:downloadURL ?downloadURL.
            BIND( ENCODE_FOR_URI(str(?downloadURL)) as ?download_url)
        }
        OPTIONAL {?file_uri mb:md5 ?md5 }
        OPTIONAL {
            ?file_uri dc:description ?description .
        }
        ?project (<>|!<>)* ?file_uri.
        ?project dc:identifier ?project_id
#        FILTER( ?project = <http://metadb.riken.jp/db/plantMetabolomics/0.1/Project/RPMM0001> ).
    FILTER( ?project = <#{ps}> ).
}
"

#sparql.query(query_file).each do |result|
#    pp result.inspect
#end
#projects ={}

files ={}
cnt = 0
#sparql.query(query_file).first(3).each do |result|
sparql.query(query_file).each do |result|
      puri = result[:project].to_s
      subject_p = RDF::URI.new("#{pfx[:mb]}#{projects[puri]}")
      subject_d = RDF::URI.new("#{pfx[:mb]}#{projects[puri]}#dataset")
      fid = result[:file_id].to_s
      unless files.key?(fid)
        cnt = cnt + 1
        files[fid] = "#{subject_p}-F#{cnt}"
        #subject_f = RDF::URI.new("#{subject_p}#F#{cnt}")
      end
      subject_f = RDF::URI.new(files[fid])
      #mtbks_id = "#{projects[puri]}-F#{cnt}"      
      graph_new << RDF::Statement.new(subject_f, RDF::RDFV.type,  RDF::URI.new("#{pfx[:mbv]}File") )
      #graph_new << RDF::Statement.new(subject_f, RDF::URI.new("#{pfx[:ddbj]}dblink"), subject_p )
      graph_new << RDF::Statement.new(subject_f, RDF::URI.new("#{pfx[:ddbj]}dblink"), subject_d )
      graph_new << RDF::Statement.new(subject_f, RDF::URI.new("#{pfx[:ddbj]}downloadURL"), result[:download_url] )
      #graph_new << RDF::Statement.new(subject_f, RDF::Vocab::DC.identifier,result[:file_id])
      graph_new << RDF::Statement.new(subject_f, RDF::Vocab::DC.identifier,"#{projects[puri]}-F#{cnt}")
      graph_new << RDF::Statement.new(subject_f, RDF::Vocab::DC.format,result[:format])
      graph_new << RDF::Statement.new(subject_f, RDF::RDFS.label,result[:name])
      graph_new << RDF::Statement.new(subject_f, RDF::Vocab::DC.description,result[:description] || "")
end

warn "### Output: rdf/#{projects[ps]}.ttl"

File.open("rdf/#{projects[ps]}.ttl","w") do |out_f|
  #puts graph_new.dump(:turtle, standard_prefixes: true, prefixes: pfx)
  out_f.write graph_new.dump(:turtle, standard_prefixes: true, prefixes: pfx)
end

end
