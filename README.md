## This project was migrated to [git-repo-sync](https://github.com/it3xl/git-repo-sync) 

### The reason is to prevent naming confusion.

I want to emphasize that **git-sync** synchronizes Git remote repositories. So, lets use **[git-repo-sync](https://github.com/it3xl/git-repo-sync)** name.

Also, I'm finishing a huge amount of development for this project (see the develop branch).  
And I'm already migrated my development to the new repository - **[git-repo-sync](https://github.com/it3xl/git-repo-sync)**

# .
## .

# gitSync

## git remote repositories synchronization

**gitSync** synchronizes git-branches between remote git-repositories.

Synchronized branches should follow a naming convention.

The naming convention is [Convention over Git](https://it3xl.blogspot.com/2017/09/convention-over-git.html).

gitSync works over HTTP only. It is because I had no chance to tune it for SSH.

gitSync synchronizes only two remote repositories for simplicity as it is a scripting solution.

gitSync do not synchronize Git-tags anymore. It's because some popular Git-servers block Git-tags deletion.

gitSync has auto conflict solving. That allows to work on the same Git-branch simultaneously.  
I.e. you can commit and merge to the same branch on both remote repositories.
In case of a conflict you have to repeat your commit.
More details on this in **Git conflicts solving**.

## Scenarios of usage

* Auto synchronization of remote Git-repositories.
* Sharing of a repository with limited internet access with your partners.
* Keeping of repositories neat and sane between customers and clients.

## Playground

If you will run **git-sync.sh** without parameters, then a test environment will be created.<br/>
You will get two remote and two local interconnected repositories on your machine.<br/>
Make changes there, run **git-sync.sh**, see behavour and results.

## How it works

Imagine, there are two remote repositories. Each repository is a separate side.<br/>
You agreed that
* the first repository owns a prefix **foo-**
* the second repository owns a prefix **bar/**
* branch names after prefixes are arbitrary.

Only branches with such the prefixes will be synchronized and visible on both sides.

## Git conflicts solving

Conflicts may occur only if your do merges or commits to another side branches.<br/>
The prefix owner will win in case of any conflicts.<br/>
Commits of a loser will be rejected, but he just has to repeat merge or commits again (from his local repository) after a Git update (fetch, pull, etc).<br/>

To know if your commit was reflected first run gitSync then do a Git update (fetch, pull, etc) in your local Git repository.  
Then look at Git commits log.

## Git-tags
I've excluded Git-tags from synchronization. Nothing wrong with tags but there are some nervous subtleties with them.

## FAQ

**Why is everything done so?** - This is a proven and working solution. But it is also modest and supported by a single person, me.<br/>
**Why do not synchronize everything at once?** - You will spend significant resources to do it professionally.<br/>
**Is it possible to synchronize all branches and tags?** - Yes. I had other [solutions and ideas](https://it3xl.blogspot.com/2018/02/approaches-to-synchronize-git-repos.html). No one is interested.<br/>
**Why do not sync Git-tags?** - This is disabled because some popular Git-servers block deletion of tags.

## I warned you

Most of the following sections describe technical details.<br/>
if you are technically savvy, I expect you will complete everything from one day to one week. Depends on your situation and needs.<br/>
The only thing I want to say, this is really working.<br/>
I am waiting for your notes and wish you luck.

## Need help?

Ask me. I'll answer on you questions ASAP.<br/>
See my contacts at [it3xl.ru](http://it3xl.ru).

## Features

* Prevention of an occasional deletion of an entire repository.
* Deletion and creation of branches from one side repository to another.
* Auto conflict solving by [Convention over Git](https://it3xl.blogspot.com/2017/09/convention-over-git.html) (non-fast-forward branch conflicts).
* Recreation of the synchronization from any position and from scratch.
* Failover & auto recovery of synchronization is supported. Especially for network troubles.
* Solution is applied per-repository (not per-server)
* Synchronization of the Git-tags was removed because GitLab loves to block tag's deletion.
* Single non-bare Git repository is used for the synchronization.
* You can attach your automations to notify about conflict solving or a branch deletion.

## Provinding credentials for Git

I use my **bash Git Credential Helper [git-cred](https://github.com/it3xl/bash-git-credential-helper)**<br/>
It passes to Git credentials from enviroment variables created by Continues Intergration tools like Jenkins.<br/>
It is **[inegrated](https://github.com/it3xl/git-sync/blob/master/repo_settings/sample_repo.sh)** now with git-sync. 

## What to expect next

**Victim Branches**

I've temporary postponed this feature. Everybody can live without it. Although it is annoying.

We have some branches that reflect all our stands (dev, test, UAT, pre-prod).  
Any commit three runs complete CI/CD processes.  
It is useful to allow any team sides to put this branches at any position, on any commit.  
I think it is time to add such branches into git-sync.

E.g.  
**victim/test-stand**  
**victim-test-stand**  

## The Glossary

Here is my [glossary](https://it3xl.blogspot.com/2018/02/glossary-of-synchronization-of-remote.html) related to the topic.

## How to Use

You need to describe the prefixes and simple details of your real remote repositories in a simple config-file.<br/>
Create the same file as [your_repo_some_name.sh](https://github.com/it3xl/git-sync/blob/master/repo_settings/sample_repo.sh).

Run the **git-sync** and pass a path to your config file as a parameter.<br/>

    bash git-sync.sh "relative_or_absolute_path/project_settings.sh"

Run **git-sync** so periodically, better once in a minute.

That's all. You may work and forget about **git-sync**.<br/>
In the case of any synchronization interruption **git-sync** will do everything right.

### Prepare Environment

Use any \*nix or Window machine.

Install Git

For \*nix users - update you bash and awk to any modern version

Tune any automation to invocate **git-sync** periodically - crons, schedulers, Jenkins, GitLab-CI, etc.

