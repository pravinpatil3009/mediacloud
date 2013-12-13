% Media Cloud Version 2
% Author David Larochelle
% December 13, 2013

# Media
  

URL                                    Function
---------------------------------      ------------------------------------------------------------
api/v2/media/single/<media_id>         Return the media source in which media_id equals <media_id>
---------------------------------      ------------------------------------------------------------

##Query Parameters 

None.

URL                                                                       Function
---------------------------------      -------------------------------------------
api/v2/media/list                      Return multiple media sources 
---------------------------------      -------------------------------------------

--------------------------------------------------------------------------------------------------------
Parameter         Default         Notes
---------------   ----------      ----------------------------------------------------------------------
 last_media_id    0               return media sources with a 
                                  media_id is greater than this value

 rows             20              Number of media sources to return. Can not be larger than 100
--------------------------------------------------------------------------------------------------------


# Media Sets

URL                                    Function
---------------------------------      ------------------------------------------------------------
api/v2/media_set/single/<media_sets_id>         Return the media source in which media_sets_id equals <media_sets_id>
---------------------------------      ------------------------------------------------------------

##Query Parameters 

None.

URL                                                                       Function
---------------------------------      -------------------------------------------
api/v2/media/list                      Return multiple media sources 
---------------------------------      -------------------------------------------

--------------------------------------------------------------------------------------------------------
Parameter             Default         Notes
-------------------   ----------      ----------------------------------------------------------------------
 last_media_sets_id    0               return media sets with 
                                       media_sets_id is greater than this value

 rows                  20              Number of media sets to return. Can not be larger than 100
--------------------------------------------------------------------------------------------------------

# Stories


URL                                    Function
------------------------------------   ------------------------------------------------------------
api/v2/stories/single/<stories_id>     Return story in which stories_id equals <stories_id>
------------------------------------   ------------------------------------------------------------

--------------------------------------------------------------------------------------------------------
Parameter             Default         Notes
-------------------   ----------      ----------------------------------------------------------------------
 raw_1st_download     0                If non-zero include the full html of the first page of the story
--------------------------------------------------------------------------------------------------------

##Multiple Stories
  
To get information on multiple stories send get requests to `api/V2/stories/list_processed`


URL                                                                       Function
---------------------------------      -------------------------------------------
api/V2/stories/list_processed           Return multiple processed stories
---------------------------------      -------------------------------------------

--------------------------------------------------------------------------------------------------------
Parameter                     Default         Notes
---------------------------   ----------      ----------------------------------------------------------
 last_processed_stories_id    0               return stories in which the processed_stories_id 
                                                is greater than this value

 rows                         20              Number of stories to return. Can not be larger than 100

 raw_1st_download      0                      If non-zero include the full html of the first
                                              page of the story
--------------------------------------------------------------------------------------------------------
  
The ‘last_processed_id’ parameter can be used to page through these results. The api will return 20 stories with a processed_id greater than this value.

NOTE: stories_id and processed_id are separate values. The order in which stories are processed is different than the story_id order. The processing pipeline involves downloading, extracting, and vectoring stories. Since unprocessed stories are of little interest, we have introduced the processed_id field to allow users to stream all stories as they’re processed.

# Story_subsets

These who want to only see a subset of stories can create a story subset stream by sending a put request to `api/v2/stories/subset/?data=<JSON> `where <JSON_STRING> is a URL encoded JSON representation of the story subset.

  
The story subset can have any of the following fields:

  
start_date

end_date 

media_id

media_sets_id

  
`start_date` and `end_date`  restrict stories based on the `publish_date` of the story. `media_id` and `media_sets_id` will restrict the stories to only include a given media source or media set.

  
For example, the following command would create a story subset for the New York Times for 1 January 2013 to 2 January 2013

    curl -X PUT  --user mediacloud-admin:password http://chloe.law.harvard.edu/admin/api/stories/subset/?data=%7B%22media_id%22%3A1%2C%22end_date%22%3A%222013-01-02%22%2C%22start_date%22%3A%222013-01-01%22%7D

  
Here the JSON string '{"media_id":1,"end_date":"2013-01-02","start_date":"2013-01-01"}' is URL encoded to %7B%22media_id%22%3A1%2C%22end_date%22%3A%222013-01-02%22%2C%22start_date%22%3A%222013-01-01%22%7D 

  
The data included in this request should be a hash with values for one or more of the following: `start_date`, `end_date`, `media_id`, and `media_sets_id`. 

The put request will return the meta-data representation of the `story_subset` including its database ID.

  
(NOTE: In the future the data parameter may be eliminated and data sent in the body of the request.)

  
It will take the backend system a while to generate the stream of stories for the newly created subset. There is a background daemon script (`mediawords_process_story_subsets.pl`) that detects newly created subsets and adds stories to them.

  
To see the status of a given subset, the client sends a get request to `api/v2/stories/subset/<ID>` where `<ID>` is the database id that was returned in the put request above.  The returned object contains a `'ready'` field with a boolean value indicating that stories from the subset have been compiled.

  
  

## Accessing a Subset of Stories
Once the story subset has been prepared it can be accessed by sending GET requests to  `api/v2/stories/list_subset_procesded/<ID>`

  
This behaves similarly to the `list_processed` URL above except only stories from the given subset are returned.


# Output Format / JSON
  
The format of the API responses is determine by the ‘Accept’ header on the request. The default is ‘application/json’. Other supported formats include 'text/html', 'text/x-json', and  'text/x-php-serialization'. It’s recommended that you explicitly set the ‘Accept’ header rather than relying on the default.

  
Here’s an example of setting the ‘Accept’ header in Python

```python  
import pkg_resources  

import requests   
assert pkg_resources.get_distribution("requests").version >= '1.2.3'
 
r = requests.get( 'http://amanda.law.harvard.edu/admin/api/stories/all_processed?page=1', auth=('mediacloud-admin', KEY'), headers = { 'Accept': 'application/json'})  

data = r.json()
```
