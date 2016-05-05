// note that these categories are copied from Slack
// be careful, there are ~20 differences in synonyms, e.g. :boom: vs. :collision:
// a few Emoji are actually missing from the Slack categories as well (?), and were added
const groups = [
  {
    name:"people",
    fullname:"tbf-retort-emojis",
    tabicon:"grinning",
    icons:[
     "laughing",
     "astonished",
     "cry",
     "rage"
    ]
  }
];

// scrub groups
groups.forEach(group => {
  group.icons = group.icons.reject(obj => !Discourse.Emoji.exists(obj));
});

// export so others can modify
Discourse.Emoji.groups = groups;

export default groups;