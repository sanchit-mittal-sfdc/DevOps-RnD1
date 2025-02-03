public inherited sharing class FutureMethodsClass 
{

    @future
    public static void sampleFutureMethod(Set<Id> contactIds)
    {
        System.debug('future method sampleFutureMethod is called');
    }

    @future(callout=true)
    public static void updateBillingAddress(Set<Id> accountIdsToUpdate)
    {

        // If there is No update permission for current user on Account object then no need to proceed further.
        // Also, I could have checked for other FLS permission here itself using 
        // schema.sObjectType.Account.fields.Location__Latitude__s.isUpdatable() but I'll be using other method in code ahead
        if( !(schema.sObjectType.Account.isUpdateable() && schema.SObjectType.Account.fields.BillingCity.isUpdateable()) )
        {
          return;  
        }
       /*
        List<Account> accList = [SELECT 
                                    Id,Location__Latitude__s, Location__Longitude__s 
                                 FROM Account 
                                 WHERE Id = :accountId];
        Account acc;
        if( accList?.size() > 0 )
        {
            acc = accList[0];
        }
        */
        List<Account> listOfAccountsToUpdate = new List<Account>();
        for( Account acc : [SELECT Id,Location__Latitude__s, Location__Longitude__s FROM Account WHERE Id IN :accountIdsToUpdate])
        {
            Account accPopulatedWithDetails = doCalloutToFetchLocation(acc);
            if( accPopulatedWithDetails != null )
            {
                listOfAccountsToUpdate.add(accPopulatedWithDetails);
            }
        }

        if( listOfAccountsToUpdate.size() > 0 )
        {
            update listOfAccountsToUpdate;
        }
    }

    public static Account doCalloutToFetchLocation(Account acc)
    {
        if (acc.Location__Latitude__s == null || acc.Location__Longitude__s == null) {
            System.debug('Account-'+acc.Name +' does not have latitude or longitude values');
            return null;
        }

        String endPointUrl = 'https://api.opencagedata.com/geocode/v1/json';
        Decimal latValue = acc.Location__Latitude__s;
        Decimal lonValue = acc.Location__Longitude__s;
        String apiKey = '1423aea6b9bb41e180db76fa9e0ab0ac';
        String finalEndPointUrl = endPointUrl + '?q=' + latValue + ',' + lonValue +'&key=' + apiKey;
        System.debug('finalEndPointUrl = '+finalEndPointUrl);

        HttpRequest req = new HttpRequest();
        req.setEndPoint(finalEndPointUrl);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');

        Http h = new Http();
        HttpResponse res;
        try
        {
            res = h.send(req);
        } 
        catch (Exception e) {
           system.debug('callout failed-'+e.getMessage()); 
           return null;
        }
        
        system.debug('STatus code-'+res.getStatusCode()); 
        if(res.getStatusCode() != 200)
        {
            
            return null;
        }

        ResponseWrapper resultWrapper = (ResponseWrapper)JSON.deserialize(res.getBody(), ResponseWrapper.class);
        system.debug(resultWrapper);

        if( resultWrapper != null && resultWrapper.results != null && resultWrapper.results.size() > 0 && resultWrapper.results[0].components != null )
        {
            acc.BillingCity = resultWrapper.results[0].components.city != null ? resultWrapper.results[0].components.city+' ' :'' + resultWrapper.results[0].components.suburb != null? resultWrapper.results[0].components.suburb + ' ':'';
        }
        else {
            return null;
        }

        //acc.BillingState = (resultWrapper.results[0].components.state != null ? resultWrapper.results[0].components.state+' ' : '')  + resultWrapper.results[0].components.county != null ?resultWrapper.results[0].components.county :'';
        acc.BillingState = resultWrapper.results[0].components.state;
        acc.BillingCountry = resultWrapper?.results[0]?.components?.country;
        acc.BillingPostalCOde = resultWrapper?.results[0]?.components?.postcode;

        return acc;
    }

    public class ResponseWrapper
    {
        List<SubWrapper> results;     
    }
    public class SubWrapper
    {
        public ComponentWrapper components;
    }

    public class ComponentWrapper
    {
        public String country;
        public String state;
        public String postcode;
        public String suburb;
        public String state_district;
        public String city;
        public String county;
        
    }
    

    
}