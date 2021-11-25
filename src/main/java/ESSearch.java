import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.entity.ContentType;
import org.apache.http.nio.entity.NStringEntity;
import org.apache.http.util.EntityUtils;
import org.opensearch.client.Request;
import org.opensearch.client.Response;
import org.opensearch.client.RestClient;

import java.io.IOException;

public class ESSearch {

    // private static String domainEndpoint = "https://esdomain.region.es.amazonaws.com ";
    private static String domainEndpoint = "https://vpc-zeppelin-com-intn-es79-hmz5tz74z2rb5reswn5ljrvkmi.eu-central-1.es.amazonaws.com";

    /*
       Connecting to production end point . SHould not work . Confirmed it is working.
     */
    // private static String domainEndpoint = "https://vpc-zeppelin-com-live-es79-xl5m2z4dahc2qz73ysncyf6gpa.eu-central-1.es.amazonaws.com";
    private static String sampleDocument = "{" + "\"title\":\"Walk the Line\"," + "\"director\":\"James Mangold\"," + "\"year\":\"2005\"}";
    private static String indexingPath = "/my-index-60/_doc";
    private static String searchPath = "/my-index-60/_search";

    public static void main(String[] args) throws IOException {
        RestClient searchClient = RestClient.builder(HttpHost.create(domainEndpoint)).build();

        // Index a document
        HttpEntity entity = new NStringEntity(sampleDocument, ContentType.APPLICATION_JSON);
        String id = "1";
        Request request = new Request("PUT", indexingPath + "/" + id);
        request.setEntity(entity);

        // Using a String instead of an HttpEntity sets Content-Type to application/json automatically.
        // request.setJsonEntity(sampleDocument);
        Response response = searchClient.performRequest(request);
        System.out.println("Index Response:" + response.toString());

        //Do a search on the index
        Request searchRequest = new Request("GET", searchPath);
        Response searchResponse = searchClient.performRequest(searchRequest);

        System.out.println("Search Response:" + searchResponse.toString());
        String rBody = EntityUtils.toString(searchResponse.getEntity());
        System.out.println("Search Body:" + rBody);
        System.out.println("Finished work. ");
        System.exit(0);
    }
}