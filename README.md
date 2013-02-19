# Cohort analysis - User retention in a Rails application.

I want my actions to be more data-driven. I want to make Dave McClure, Steve Blank, and Eric Ries proud. But, it's easier said than done. 

Analytics are still a pain in the ass. 

How can I tell if people are using my product, [Draft](https://draftin.com/)? ([Draft is the tool I'm working on to help people become better writers](http://ninjasandrobots.com/draft-version-control-for-writing).) 

I could look at user retention. Once people start using Draft, do they come back to use it again? 

There's some great software to help study how users return to your product. They use a method called cohort analysis, which breaks up users into groups of people who "activate" or sign-up at the same time and then you track their progress as a group. Do users that signup in January after one month use your app more than those users who signed up in December after their first month? They do? Awesome, those features and things you did in February might be onto something.

To use these analytics tools, I have to integrate my application with them. I have to figure out how to send even more data to them.  

But I don't want to integrate something else right now. I already have data. It's coming out of my ears. A database full of it. Log files upon log files. Can't some of the data I already have power this user retention analysis? Do I really have to start all over again collecting new data?

I don't want to work harder for more data right now. I want the data to work harder for me.

I got irritated, so I built a simple way to study your Rails app's user retention using a cohort analysis with the data you already have in your database. It's called CohortMe.

[https://github.com/n8/cohort_me](https://github.com/n8/cohort_me)

To get a cohort analysis, just use this in your Rails app: 

```
CohortMe.analyze(activation_class: Document)
```

That's it. 

Above is an example of studying user retention for Draft. Users are "activated" once they create their first Document. Then they "return" if they create another Document. 

CohortMe.analyze will spit out a ruby Hash: 

```
{Mon, 21 Jan 2013=>{:count=>[15, 1, 1, 0], :data=>[#<Document user_id: 5, created_at: "2013-01-22 18:09:15">,
```

During the week starting on 21 Jan 2013, I had 15 people signup. One week later, I only had 1 user still creating Documents. Yuck. That's a terrible retention rate. I better explore why they aren't coming back. **Note:** it's just bogus test data.

[Here's some partial view code you can use](https://raw.github.com/n8/cohort_me/master/lib/cohort_me/_cohort_table.html.erb) to show your cohort analysis in a nice table: 

![](http://i.imgur.com/qBbkZv8.png)

Pretty easy. If you have any trouble let me know on [Twitter](https://twitter.com/natekontny) or email.



CohortMe Details
----------------

Options you can pass to CohortMe.analyze:

* :period - Default is "weeks". Can also be "months" or "days".
* :activation_class - The Rails model class that CohortMe will query to find activated users. For example: User. CohortMe will look for a created_at timestamp in this table.
* :activation_user_id - Default is "user_id". Most Rails models are owned by a User through a "user_id". If it's something else like "owner_id", you can override that here.
* :activation_conditions - If you need anything fancy to find activated users. For example, if your acivation_class is Document (meaning find activated Users who have created their first Document) you could pass in:  :activation_conditions => ["(content IS NOT NULL && content != '')], which means: Find activated Users who have create their first Document that has non-empty content.
* :activity_class - Default is the same class used as the activation_class. However, is there a different Class representing an Event the user creates in your database when they revisit your application? Do you expect users to create a new Message each week? Or a new Friend?
* :activity_user_id - Defaults to "user_id". 


Examples
--------- 

First, figure out who your activated users are. Are they simply Users in your database? Could be. But I prefer treating an active user as someone who has signed up AND done a key feature. 

For example, if you created a group messaging app, it's probably a User when they created their first Group.

Next, figure out what a user does to be classified as "returning". This needs to be another record in your database. Is it a Message they made this week? A Share? A new Document?

For my group messaging tool, my cohort analysis might look like this: 

```
@cohorts = CohortMe.analyze(period: "months", 
                            activation_class: Group, 
                            activity_class: Message)
```

CohortMe will look at Groups to find activated users: people who created their first Group. Next, CohortMe will look to the Message model to find out when those users have returned to my app to create that Message activity. 

This assumes a Group belongs to a user through an attribute called "user_id". But if the attribute is "owner_id" on a Group, that's fine, you can do: 

```
@cohorts = CohortMe.analyze(period: "months", 
                            activation_class: Group, 
                            activation_user_id: 'owner_id',
                            activity_class: Message)
```

Here's an example from Draft. It's slightly more complicated because I have guest users, and documents that can be blank from people kicking the tires. I don't want to count those. My cohort analysis looks like this: 

```
non_guests = User.where("encrypted_password IS NOT NULL AND encrypted_password != ''").all
@period = "weeks"
activation_conditions = ["(content IS NOT NULL && content != '') and user_id IN (?)", non_guests]

@cohorts = CohortMe.analyze(period: @period, 
                                activation_class: Document, 
                                activation_conditions: activation_conditions)
```

Data Returned
-------------
The data returned looks like this: 

```
{cohort date1 => {
    :count=>[integer, smaller integer, smaller integer], 
    :data=>[user event record, user event record]
}
```

Installation
------------

- Add `gem 'cohort_me'` to your Gemfile.
- Run `bundle install`.
- Restart your server 
- Get your cohorts in a controller action. For example:

```
class Users
   def performance
       @cohorts = CohortMe.analyze(period: "weeks", 
                                   activation_class: Document)
       render action: 'performance'
   end
end
```

- Do something with @cohorts in a view. 
[Here's code you can use for your view](https://raw.github.com/n8/cohort_me/master/lib/cohort_me/_cohort_table.html.erb). It displays a basic cohort analysis table you can play with. 
- If you look closely at that table image, you'll notice that the numbers are links. I've tweaked the table in my own app to be able to show me who exactly are those users returning to Draft. You can do the same: 

```
<%= link_to "#{((row[1][:count][i].to_f/start.to_f) * 100.00).round(0)}%", show_users_retention_path(cohort: row[0], period: i) %>
```

And I have a Controller action that looks like this: 

```
class RetentionController < ApplicationController

  def show_users
    @cohorts = CohortMe.analyze(activation_class: Document)

    @documents = @cohorts[Date.parse(params[:cohort])][:data].select{|d| d.periods_out.to_i == params[:period].to_i}

    user_ids = @documents.collect{|d| d.user_id }
    @users = User.where("id IN (?)", user_ids)
    
  end
end
```

Feedback
--------
[Source code available on Github](https://github.com/n8/cohort_me). Feedback and pull requests are greatly appreciated.  


